pragma solidity >=0.4.21 <0.7.0;
pragma experimental ABIEncoderV2;

contract Products{
    // PRODUCT
    struct product{
        uint id;

        string name;
        uint categoryId;
        uint price;
        string imageHash;
        string userId;
        uint sellerPicksEndTimestamp;

        bool isDeleted;
    }

    uint public productCount = 0;
    mapping(uint => product) public products;

    // event ProductAdded(
    //     uint id,
    //     string name,
    //     uint price,
    //     string imageHash,
    //     string userId,
    //     bool isdeleted
    // );

    function addProduct
                (string memory _name, uint _categoryId, uint _price, string memory _imageHash, string memory _userId) public {
        require(bytes(_name).length > 0, 'Add product failed, name not null is required');
        require(_price > 0, 'Add product failed, price > 0 is required');

        productCount++;
        products[productCount] = product(productCount, _name, _categoryId, _price, _imageHash, _userId, 0, false);
        // emit ProductAdded(productCount, _name, _price, 0, _imageHash, _userId, false);
    }

    function updateProduct
        (uint _id, string memory _name, uint _categoryId, uint _price, string memory _imageHash, string memory _userId, bool _isDeleted)
    public {
        product memory _oldProduct = products[_id];
        product memory _newProduct = product(_id, _name, _categoryId, _price, _imageHash, _userId, _oldProduct.sellerPicksEndTimestamp, _isDeleted);

        require(!equals(_oldProduct, _newProduct), 'New product value must be different from old value');

        products[_id] = _newProduct;
    }

    function equals(product memory _first, product memory _second) internal pure returns (bool) {
        // Just compare the output of hashing all fields packed
        return(keccak256(abi.encodePacked(_first.name, _first.categoryId, _first.price,
            _first.imageHash, _first.userId, _first.sellerPicksEndTimestamp, _first.isDeleted)) == keccak256(abi.encodePacked(_second.name, 
            _second.categoryId, _second.price, _second.imageHash, _second.userId, _second.sellerPicksEndTimestamp, _second.isDeleted)));
    }

    function updateProductSellerPicks(uint _id, uint _sellerPicksEndTimestamp) public {
        products[_id].sellerPicksEndTimestamp = _sellerPicksEndTimestamp;
    }

    // CATEGORY
    struct category{
        uint id;

        string name;

        bool isDeleted;
    }

    uint public categoryCount = 0;
    mapping(uint => category) public categories;

    function addCategory(string memory _name) public {
        categoryCount++;
        categories[categoryCount] = category(categoryCount, _name, false);
    }

    function updateCategory(uint _id, string memory _name, bool _isDeleted) public {
        category memory _oldCategory = categories[_id];
        category memory _newCategory = category(_id, _name, _isDeleted);

        require(keccak256(abi.encodePacked(_newCategory.name)) != keccak256(abi.encodePacked(_oldCategory.name)) ||
        _newCategory.isDeleted != _oldCategory.isDeleted, 'New value must be different from old value');

        categories[_id] = _newCategory;
    }

    // event ProductPurchased(
    //     uint id,

    //     uint productId,
    //     string userId,
    //     uint totalPrice,
    //     uint amount,
    //     uint timestamp
    // );

    // PURCHASE INFO
    struct purchaseInfo{
        uint id;

        uint detailsCount;
        mapping(uint => uint) productIds;
        mapping (uint => uint) amounts;
        mapping (uint => uint) unitPrices;

        string buyerId;
        uint shipTimestamp;
        uint deliverTimestamp;
        string saleId;
        string phoneNumber;
        string userAddress;

        string pin;
        string status;
    }

    uint public purchaseInfoCount = 0;
    mapping(uint => purchaseInfo) public purchaseInfos;

    function getPurchaseInfoProductId(uint purchaseInfoId, uint purchaseInfoDetailId) public view returns (uint) {
        return purchaseInfos[purchaseInfoId].productIds[purchaseInfoDetailId];
    }

    function getPurchaseInfoAmount(uint purchaseInfoId, uint purchaseInfoDetailId) public view returns (uint) {
        return purchaseInfos[purchaseInfoId].amounts[purchaseInfoDetailId];
    }

    function getPurchaseInfoUnitPrice(uint purchaseInfoId, uint purchaseInfoDetailId) public view returns (uint) {
        return purchaseInfos[purchaseInfoId].unitPrices[purchaseInfoDetailId];
    }

    function purchaseProduct(uint[] memory _productIds, string memory _buyerId, address payable[] memory _sellerAddresses, uint[] memory _amounts, string memory _saleId, uint _saleOff, string memory _phoneNumber, string memory _userAddress, address payable _siteAddress, uint _commission, string memory _pin)
        public payable {

        uint totalPrice = 0;
        for (uint i = 0; i < _productIds.length; i++)
            totalPrice += products[_productIds[i]].price * _amounts[i];
        totalPrice -= totalPrice * _saleOff / 100;
        require(msg.value >= totalPrice * 1e18, 'Purchase product failed, not enough value to buy');

        purchaseInfoCount++;
        purchaseInfos[purchaseInfoCount] = purchaseInfo
                                            (purchaseInfoCount, _productIds.length, _buyerId, now, 0, _saleId, _phoneNumber, _userAddress, _pin, "Đang giao");

        for (uint i = 0; i < _productIds.length; i++) {
            purchaseInfos[purchaseInfoCount].productIds[i + 1] = _productIds[i];
            purchaseInfos[purchaseInfoCount].amounts[i + 1] = _amounts[i];
            purchaseInfos[purchaseInfoCount].unitPrices[i + 1] = products[_productIds[i]].price;
            totalPrice = products[_productIds[i]].price * _amounts[i];
            totalPrice -= totalPrice * _saleOff / 100;
            address(_sellerAddresses[i]).transfer(totalPrice * (100 - _commission) / 100 * 1e18);
            address(_siteAddress).transfer(totalPrice * (_commission) / 100 * 1e18);
        }
        purchaseInfos[purchaseInfoCount].detailsCount = _productIds.length;

        // emit ProductPurchased(purchaseInfoCount, _productId, _userId, _product.price * _amount, _amount, now);
    }

    function comfirmDelivered(uint _id, string memory _pin) public {
        require(keccak256(abi.encodePacked(purchaseInfos[_id].pin)) == keccak256(abi.encodePacked(_pin)), 'Pin is not correct');

        purchaseInfos[_id].deliverTimestamp = now;
        purchaseInfos[_id].status = "Đã giao";
    }

    // SELLER PICKS
    struct sellerPicks{
        uint id;

        string totalPrice;
        uint productId;
        uint quantity;
    }

    uint public sellerPicksCount = 0;
    mapping(uint => sellerPicks) public sellerPicksList;

    function sellerPicksPurchase(string memory _totalPrice, uint _productId, uint _quantity, address payable _siteAddress) public payable {
        address(_siteAddress).transfer(msg.value);

        sellerPicksCount++;
        sellerPicksList[sellerPicksCount] = sellerPicks(sellerPicksCount, _totalPrice, _productId, _quantity);
        
        uint addDate = 60 * 60 * 24 * _quantity;
        if (products[_productId].sellerPicksEndTimestamp < now)
            products[_productId].sellerPicksEndTimestamp = now + addDate;
        else 
            products[_productId].sellerPicksEndTimestamp += addDate;
    }
}