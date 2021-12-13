// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Address.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";
import "./TokenSupport.sol";
import "./MarketOrders.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @dev FreeMarkt.
 */
contract FreeMarketMultiToken is ReentrancyGuard, MarketOrders, TokenSupport {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC721 public PlatoNft;    // NFT token of Plato
    address payable public govAddress;
    uint256 public fee = 500;
    uint256 public feeML = 1000;
    uint256 public baseMax = 10000;
    uint256 public constant itemMax = 1000000000;    // for calculate the itemId

    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;          // ETH/BNB/HT/OKT
    // address public WETH = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;         // WETH/WBNB/WHT/WOKT
    
    event Sell(address indexed sender, address indexed currencyAddress, uint256 time, uint256 orderId, uint256 price, uint256 amount, uint256[] tokenIdArr);
    event Buy(address indexed sender, uint256 time, uint256 orderId, uint256 amount);
    event Revoke(address indexed sender, uint256 time, uint256 orderId, uint256[] tokenIdArr);
    event ModifyPrice(address indexed sender, uint256 time, uint256 orderId, uint256 newPrice);

    constructor(address _platoNft, address payable _gov, uint256[] memory _initTokenIdArr) public {
        require(_platoNft != address(0), "Nft zero address");
        require(_gov != address(0), "Gov zero address");

        PlatoNft = IERC721(_platoNft);
        govAddress = _gov;
        // init order
        Order memory _initOrder = Order(
            0,
            address(0),
            address(0),
            0,
            block.timestamp,
            block.timestamp,
            0,
            0,
            _initTokenIdArr
        );
        // init The array of tokenId
        orderList.push(_initOrder);
    }

    function getItem(uint256 _tokenId) internal pure returns(uint256) {
        return _tokenId.div(itemMax);
    }

    function isVerified(uint256[] memory tokenIdArr) internal pure returns(bool) {
        if (tokenIdArr.length == 1) {
            return true;
        }
        for (uint256 i = 0; i < tokenIdArr.length - 1; i++) {
            if (getItem(tokenIdArr[i]) != getItem(tokenIdArr[i + 1])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Add a order to list.
     */
    function placeOrder(address _currencyAddress, uint256 price, uint256 amount, uint256[] memory tokenIdArr) nonReentrant public {
        require(price > 0, "placeOrder: NFT price is 0");
        require(amount > 0, "placeOrder: NFT amount at least 1");
        require(amount == tokenIdArr.length, "placeOrder: NFT quantity does not match");
        require(_currencyAddress == ETH || _currencyAddress.isContract(), "placeOrder: The currency address is incorrect");

        if (amount >= 2) { // Require all NFTs to be the same
            require(isVerified(tokenIdArr), "placeOrder: NFT tokenId error");
        }

        for (uint256 i = 0; i < tokenIdArr.length; i++) {
            PlatoNft.transferFrom(msg.sender, address(this), tokenIdArr[i]);
        }

        uint256 orderId = _add(Order({
            id: 0,     
            owner: msg.sender,
            currencyAddress: _currencyAddress,
            price: price, 
            createTime: block.timestamp,
            updateTime: 0,
            amount: amount, 
            remain: amount, 
            nfts: tokenIdArr
        }));

        emit Sell(msg.sender, _currencyAddress, block.timestamp, orderId, price, amount, tokenIdArr);
    }

    /**
     * @dev Buy a order to tranfer nft.
     */
    function proxyTransfer(uint256 amount, uint256 index, Order memory order) internal {

        for (uint256 i = order.remain - 1; i >= order.remain - amount; i--) {
            PlatoNft.transferFrom(address(this), msg.sender, order.nfts[i]);
            if (i == 0) {
                break;
            }
        }

        if (order.remain == amount) {
            _remove(order.id);
        } else {
            for (uint256 i = order.remain - 1; i >= order.remain - amount; i--) {
                orderList[index].nfts.pop();
            }
            orderList[index].remain = orderList[index].remain - amount;
        }

        emit Buy(msg.sender, block.timestamp, order.id, amount);
    }

    function checkOrder(uint256 amount, uint256 orderId) internal view returns(uint256 index, Order memory order) {
        require(amount > 0, "checkOrder: NFT purchase amount at least 1");
        index = orderIndex[orderId];
        require(contains(index), "checkOrder: Order not exists");

        order = at(index);
        require(order.owner != msg.sender, "checkOrder: Buyer is owner of order");
        require(order.remain >= amount, "checkOrder: Order's nft not enough");

        return (index, order);
    }

    /**
     * @dev Buy a order in token.
     */
    function buyOrderInToken(uint256 amount, uint256 orderId) nonReentrant public {

        (uint256 index, Order memory order) = checkOrder(amount, orderId);
        
        uint256 _tokenAmt = order.price.mul(amount);
        require(
            _tokenAmt <= IERC20(order.currencyAddress).balanceOf(msg.sender),
            "buyOrderInToken: insufficient balance"
        );

        if (fee > 0) {
            uint256 fee_ = _tokenAmt.mul(fee).div(baseMax);
            IERC20(order.currencyAddress).safeTransferFrom(msg.sender, govAddress, fee_);
            _tokenAmt = _tokenAmt.sub(fee_);

            if (_tokenAmt > 0) {
                IERC20(order.currencyAddress).safeTransferFrom(msg.sender, order.owner, _tokenAmt);
            }
        }

        proxyTransfer(amount, index, order);
    }

    /**
     * @dev Buy a order in eth.
     */
    function buyOrderInETH(uint256 amount, uint256 orderId) nonReentrant public payable {

        (uint256 index, Order memory order) = checkOrder(amount, orderId);

        require(order.currencyAddress == ETH, "buyOrderInETH: Non-eth order");
        
        uint256 _ethAmt = order.price.mul(amount);
        require(_ethAmt == msg.value, "buyOrderInETH: insufficient balance");

        if (fee > 0) {
            uint256 fee_ = _ethAmt.mul(fee).div(baseMax);
            govAddress.transfer(fee_);
            _ethAmt = _ethAmt.sub(fee_);

            if (_ethAmt > 0) {
                payable(order.owner).transfer(_ethAmt);
            }
        }

        proxyTransfer(amount, index, order);
    }

    /**
     * @dev Revoke a order to list.
     */
    function revokeOrder(uint256 orderId) nonReentrant public {

        uint256 index = orderIndex[orderId];
        require(contains(index), "revokeOrder: Order not exists");

        Order memory order_ = at(index);

        require(order_.owner == msg.sender, "revokeOrder: Caller is not the owner of order");

        for (uint256 i = 0; i < order_.remain; i++) {
            PlatoNft.transferFrom(address(this), msg.sender, order_.nfts[i]);
        }

        _remove(order_.id);
        
        emit Revoke(msg.sender, block.timestamp, orderId, order_.nfts);
    }

    /**
     * @dev Revoke a order to list.
     */
    function modifyPrice(uint256 orderId, uint256 _newPrice) nonReentrant public {

        require(_newPrice > 0, "modifyPrice: new price cannot be 0");

        uint256 index = orderIndex[orderId];
        require(contains(index), "modifyPrice: Order not exists");
        require(at(index).owner == msg.sender, "modifyPrice: Permit not call unless owner of order");

        orderList[index].price = _newPrice;
        orderList[index].updateTime = block.timestamp;

        emit ModifyPrice(msg.sender, block.timestamp, orderId, _newPrice);
    }
    
    function getTokenIdArrByIndex(uint256 index) public view returns(uint256[] memory) {
        return at(index).nfts;
    }

    function getTokenIdArrById(uint256 orderId) public view returns(uint256[] memory) {
        uint256 index = orderIndex[orderId];
        require(contains(index), "getTokenIdArrById: Order not exists");

        return at(index).nfts;
    }

    function setFee(uint256 _fee) public onlyOwner {
        require(_fee <= feeML,"setFee: fee over limit");
        fee = _fee;
    }

    // Prevent accidentally transferring the other token to the contract
    function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) public onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function takeOutEth() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }
}
