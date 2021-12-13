// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

/**
 * @dev MarketOrders.
 */
contract MarketOrders {

    struct Order {
        uint256 id;                 // order id
        address owner;              // owner of place order
        address currencyAddress;    // currency address of place order
        uint256 price;              // currency amount (price of per nft)
        uint256 createTime;         // The time of create order
        uint256 updateTime;         // The time of modify order
        uint256 amount;             // The amount of tokenId
        uint256 remain;             // The remaining amount of tokenId
        uint256[] nfts;             // The array of tokenId
    }

    uint256 public orderNonce;
    Order[] public orderList;

    mapping (uint256 => uint256) public orderIndex;    // orderId => orderIndex

    /**
     * @dev Add a order to list.
     * Returns true or false
     */
    function _add(Order memory _order) internal returns (uint256) {
        orderNonce++;
        _order.id = orderNonce;
        orderIndex[_order.id] = length();
        orderList.push(_order);

        return _order.id;
    }

    /**
     * @dev Removes the order from order list.
     * Returns true if the order was removed from the list.
     */
    function _remove(uint256 _orderId) internal returns (bool) {

        require(_orderId >= 1, "_remove: no orderId in list");
        require(orderList.length >= 1, "_remove: no order in list");

        uint256 index = orderIndex[_orderId];
        uint256 lastIndex = orderList.length - 1;

        if (orderIndex[_orderId] != lastIndex) {
            orderList[index] = orderList[lastIndex];
            orderIndex[orderList[index].id] = index;
        }

        orderList.pop();
        delete orderIndex[_orderId];

        return true;
    }

    // function _remove(uint256 _orderId) internal returns (bool) {

    //     require(_orderId >= 1, "_remove: no orderId in list");
    //     require(orderList.length >= 1, "_remove: no order in list");
    //     uint256 index = orderIndex[_orderId];
    //     uint256 lastIndex = orderList.length - 1;
    //     if (orderIndex[_orderId] == lastIndex) {
    //         orderList.pop();
    //         delete orderIndex[_orderId];
    //         return true;
    //     }
    //     orderList[index] = orderList[lastIndex];
    //     orderIndex[orderList[index].id] = index;
    //     orderList.pop();
    //     delete orderIndex[_orderId];

    //     return true;
    // }

    /**
     * @dev Returns true if the order is in the list.
     */
    function contains(uint256 index) public view returns (bool) {
        return orderList[index].owner != address(0);
    }

    /**
     * @dev Returns the number of order on the list.
     */
    function length() public view returns (uint256) {
        return orderList.length;
    }

    /**
     * @dev Returns the order stored at position `index` in the list.
     * Requirements: - `index` must be strictly less than {length}.
     */
    function at(uint256 index) public view returns (Order memory) {
        require(length() > index, "MarketOrders: index out of bounds");
        return orderList[index];
    }

}
