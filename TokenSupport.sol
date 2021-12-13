// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract TokenSupport is Ownable {

    struct TokenInfo {
        string currencySymbol;              // Current currency symbol of NFT
        uint256 currencyDecimals;           // Current currency decimals of NFT
        address currencyAddress;            // Current payment currency of NFT
    }

    mapping(address => TokenInfo) public tokenInfo;
    mapping(string => TokenInfo) public tokenSymbolMap;
    mapping(uint256 => TokenInfo) public tokenIndexMap;
    mapping(address => uint256) public tokenIndex;

    TokenInfo[] public tokenList;

    /**
     * @dev Add tokenInfo into tokenList.
     */
    function _addToken(string memory _currencySymbol, uint256 _currencyDecimals, address _currencyAddress) public onlyOwner {

        require(_currencyAddress != address(0), "_addToken: currencyAddress is zero address");
        require(tokenSymbolMap[_currencySymbol].currencyAddress == address(0), "_addToken: currencySymbol already exists");
        require(tokenInfo[_currencyAddress].currencyAddress == address(0), "_addToken: currencyAddress already exists");
        require(_currencyDecimals > 0, "_addToken: currencyDecimals is zero decimals");

        TokenInfo memory _tokenInfo = TokenInfo(_currencySymbol, _currencyDecimals, _currencyAddress);
        uint256 _index = tokenList.length;
        tokenIndexMap[_index] = _tokenInfo;

        tokenSymbolMap[_currencySymbol] = _tokenInfo;
        tokenInfo[_currencyAddress] = _tokenInfo;
        tokenIndex[_currencyAddress] = _index;

        tokenList.push(_tokenInfo);
    }

    /**
     * @dev Batch add tokenInfo into tokenList.
     */
    function _batchAddToken(TokenInfo[] memory _tokenList) public onlyOwner {

        for (uint256 i = 0; i < _tokenList.length; i++) {
            _addToken(
                _tokenList[i].currencySymbol,
                _tokenList[i].currencyDecimals,
                _tokenList[i].currencyAddress
            );
        }
    }

    /**
     * @dev Update tokenInfo by index.
     */
    function _updateTokenByIndex(uint256 _index, string memory _currencySymbol, uint256 _currencyDecimals, address _currencyAddress)
        public
        onlyOwner
    {
        require(
            _currencyAddress != address(0),
            "_updateTokenByIndex: the currency address to be added is zero address"
        );
        require(
            tokenIndexMap[_index].currencyAddress != address(0),
            "_updateTokenByIndex: the token corresponding to the index does not exist"
        );

        TokenInfo memory _oldTokenInfo = tokenIndexMap[_index];
        address oldAddress = _oldTokenInfo.currencyAddress;
        string memory oldSymbol = _oldTokenInfo.currencySymbol;

        delete tokenIndex[oldAddress];
        delete tokenInfo[oldAddress];
        delete tokenSymbolMap[oldSymbol];

        tokenIndexMap[_index].currencySymbol = _currencySymbol;
        tokenIndexMap[_index].currencyAddress = _currencyAddress;
        tokenIndexMap[_index].currencyDecimals = _currencyDecimals;

        tokenIndex[_currencyAddress] = _index;
        tokenInfo[_currencyAddress] = tokenIndexMap[_index];
        tokenSymbolMap[_currencySymbol] = tokenIndexMap[_index];
        
        tokenList[_index] = tokenIndexMap[_index];

    }

    /**
     * @dev Update tokenInfo by address.
     */
    function _updateTokenByAddress(address _currencyAddress, string memory _currencySymbol, uint256 _currencyDecimals)
        public
        onlyOwner
    {
        require(
            tokenInfo[_currencyAddress].currencyAddress != address(0),
            "_updateTokenByAddress: the currency address to be updated does not exist"
        );
        require(
            _currencyDecimals > 0,
            "_updateTokenByAddress: currencyDecimals is zero decimals"
        );

        TokenInfo memory _oldTokenInfo = tokenInfo[_currencyAddress];
        string memory oldSymbol = _oldTokenInfo.currencySymbol;
        uint256 oldIndex = tokenIndex[_currencyAddress];

        delete tokenSymbolMap[oldSymbol];
        delete tokenIndexMap[oldIndex];

        tokenInfo[_currencyAddress].currencySymbol = _currencySymbol;
        tokenInfo[_currencyAddress].currencyDecimals = _currencyDecimals;

        tokenSymbolMap[_currencySymbol] = tokenInfo[_currencyAddress];
        tokenIndexMap[oldIndex] = tokenInfo[_currencyAddress];

        tokenList[oldIndex] = tokenInfo[_currencyAddress];
    }

    /**
     * @dev Update tokenInfo by symbol.
     */
    function _updateTokenBySymbol(string memory _currencySymbol, address _currencyAddress, uint256 _currencyDecimals)
        public
        onlyOwner
    {
        require(
            tokenSymbolMap[_currencySymbol].currencyAddress != address(0),
            "_updateTokenBySymbol: the currency symbol to be updated does not exist"
        );
        require(
            _currencyAddress != address(0),
            "_updateTokenBySymbol: currencyAddress is zero address"
        );
        require(
            _currencyDecimals > 0,
            "_updateTokenBySymbol: currencyDecimals is zero decimals"
        );

        TokenInfo memory _oldTokenInfo = tokenSymbolMap[_currencySymbol];
        address oldAddress = _oldTokenInfo.currencyAddress;
        uint256 oldIndex = tokenIndex[oldAddress];

        delete tokenInfo[oldAddress];
        delete tokenIndex[oldAddress];
        delete tokenIndexMap[oldIndex];

        tokenSymbolMap[_currencySymbol].currencyDecimals = _currencyDecimals;
        tokenSymbolMap[_currencySymbol].currencyAddress = _currencyAddress;

        tokenIndex[_currencyAddress] = oldIndex;
        tokenIndexMap[oldIndex] = tokenSymbolMap[_currencySymbol];
        tokenInfo[_currencyAddress] = tokenSymbolMap[_currencySymbol];

        tokenList[oldIndex] = tokenSymbolMap[_currencySymbol];
    }

    /**
     * @dev remove tokenInfo by symbol.
     */
    function _removeTokenByIndex(uint256 _index) public onlyOwner {
        require(_index < tokenCount(), "_removeTokenByIndex: index out of bounds");
        require(
            tokenIndexMap[_index].currencyAddress != address(0),
            "_removeTokenByIndex: the currency index to be updated does not exist"
        );
        uint256 lastIndex = tokenCount() - 1;

        TokenInfo memory _oldTokenInfo = tokenIndexMap[_index];
        string memory oldSymbol = _oldTokenInfo.currencySymbol;
        address oldAddress = _oldTokenInfo.currencyAddress;

        if (_index != lastIndex) {
            
            _updateTokenByIndex(
                _index,
                tokenIndexMap[lastIndex].currencySymbol,
                tokenIndexMap[lastIndex].currencyDecimals,
                tokenIndexMap[lastIndex].currencyAddress
            );

            tokenList.pop();

            delete tokenSymbolMap[oldSymbol];
            delete tokenInfo[oldAddress];
            delete tokenIndex[oldAddress];
            delete tokenIndexMap[lastIndex];

            return;
        }


        tokenList.pop();

        delete tokenSymbolMap[oldSymbol];
        delete tokenInfo[oldAddress];
        delete tokenIndex[oldAddress];
        delete tokenIndexMap[_index];

    }

    function tokenCount() public view returns(uint256) {
        return tokenList.length;
    }

    function getTokenInfo(address _currencyAddress) public view returns(TokenInfo memory) {
        require(
            tokenInfo[_currencyAddress].currencyAddress != address(0),
            "getTokenInfo: the currency address does not exist"
        );

        return tokenInfo[_currencyAddress];
    }

    function getTokenSymbolMap(string memory _currencySymbol) public view returns(TokenInfo memory) {
        require(
            tokenSymbolMap[_currencySymbol].currencyAddress != address(0),
            "getTokenSymbolMap: the currency symbol does not exist"
        );

        return tokenSymbolMap[_currencySymbol];
    }

    function getTokenIndexMap(uint256 _index) public view returns(TokenInfo memory) {
        require(
            tokenIndexMap[_index].currencyAddress != address(0),
            "getTokenIndexMap: the token corresponding to the index does not exist"
        );

        return tokenIndexMap[_index];
    }

    function getTokenIndex(address _currencyAddress) public view returns(uint256) {
        uint256 _index = tokenIndex[_currencyAddress];
        require(
            tokenIndexMap[_index].currencyAddress != address(0),
            "getTokenIndex: the token corresponding to the index does not exist"
        );
        return tokenIndex[_currencyAddress];
    }

}
