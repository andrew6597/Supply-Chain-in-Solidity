// SPDX-License-Identifier: GPL-1.0
// Creative Commons Attribution 1.0 Generic
//Contract will be compiled on version 0.7.0 or greater
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.0;

//Smart Contract

contract coffesupply{

    struct Shipment {
        uint transfer_id;
        uint product_id;
        string product_name;
        string origin;
        string destination;
        string departure_date;
        string expected_arr_date; // The date that the transfer company promises that they will deliver the product
        string creator; //The creator of each shipment
        bool delivered; // When True : Shipment is closed and the product is delivered
        string arrival_date; // The date that the product was actually delivered
    }// Shipment

    struct product{
        uint product_id;
        uint [] ship_product; //We keep all the IDs of the product shipments.
        string product_name;
        string production_date;
        string expiration_Date;
        string product_region;
        string stage; //A variable to set in which stage is the product live.
        bool shelf; //True = The product is available for customers
    }//Product

    struct User {
        address user_address;
        string role;
        uint role_id;
    } //User

    struct ProductInfo {
        uint productId;
        string productName;
        string productRegion;
    }//ProductInfo. A struct that we'll use for 2 view functions, to get some of the information

    // Setting with constant variable the addresses of the 3 users
    address constant private SupplyUser = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    address constant private FactoryUser = 0x583031D1113aD414F02576BD6afaBfb302140225;
    address constant private StoreUser = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB;

    //Let's now create the some mappings and make them private.
    mapping(address => User) private users;
    mapping(address => bool) private userCheck; //mapping to check if the user is valid
    mapping(uint => product) private products;
    mapping(uint => Shipment) private shipments;


    constructor() {
        userCheck[SupplyUser] = true;
        users[SupplyUser] = User(SupplyUser, "Supply Manager",1);
        userCheck[FactoryUser] = true;
        users[FactoryUser] = User(FactoryUser, "Factory Manager",2);
        userCheck[StoreUser] = true;
        users[StoreUser] = User(StoreUser, "Store Manager",3);
    } // We initialized that only these 3 people are authorized by the system and we'll use that authorization
      // in a way that no one but them can create products and transfers.

    //We'll initialize 2 variables that we'll use as product & shipment IDs.
    uint private ShipmentCount = 0;
    uint private ProductCount = 0;


    function createProduct(string memory _productName, string memory _productionDate, string memory _expirationDate, string memory _product_region) public returns(uint) {
        require (userCheck[msg.sender], "Unauthorized Access"); //First, check if a random wallet try to create a product
        require(users[msg.sender].role_id == 1, "Only the Supply Manager can create products");
        ProductCount ++;
        products[ProductCount] = product(ProductCount, new uint[](0) , _productName, _productionDate, _expirationDate, _product_region, "Supply", false);
        return ProductCount;
    }//createProduct
    // We used new uint[](0) so we can initialize the shipment ids of the product as an empty list .

    function createShipment(uint _productId, string memory _origin, string memory _destination, string memory _departureDate, string memory _expArrival) public returns(uint) {
        require (userCheck[msg.sender], "Unauthorized Access");
        require(products[_productId].product_id == _productId, "Product with given ID does not exist");
        //Check if the user is authorized to create that specific shipment via their role
        bool authorized = false;
        string memory temp; //Temporary Variable to get the stage of the product.
        if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Supply Manager"))) {
            if (keccak256(bytes(_origin)) == keccak256(bytes("Supply")) && keccak256(bytes(_destination)) == keccak256(bytes("Factory")) && keccak256(abi.encodePacked(products[_productId].stage)) == keccak256(abi.encodePacked("Supply"))) {
                authorized = true;
                temp = "Transfering to Factory";
            }
        } else if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Factory Manager"))) {
            if (keccak256(bytes(_origin)) == keccak256(bytes("Factory")) && keccak256(bytes(_destination)) == keccak256(bytes("Store")) && keccak256(abi.encodePacked(products[_productId].stage)) == keccak256(abi.encodePacked("Factory"))) {
                authorized = true;
                temp = "Delivering to Store";
            }
        }
        require(authorized, "Unauthorized user role");
        ShipmentCount ++;
        shipments[ShipmentCount] = Shipment(ShipmentCount, _productId, products[_productId].product_name , _origin, _destination, _departureDate, _expArrival, users[msg.sender].role,false, "Pending");
        products[_productId].stage = temp;
        products[_productId].ship_product.push(ShipmentCount); //Every time that a shipment is created, we append that shipment Id to the ship_product list. This way each product has a history of its shipments
        return ShipmentCount;
    }//createShipment

    //We create a getProduct function, that any authorized member can call it and have a full view of the product information.
    function getProduct(uint _productId) public view returns (product memory) {
        require (userCheck[msg.sender], "Only Product User, Factory User or Store User can call this function." );
        require(products[_productId].product_id == _productId, "Product with given ID does not exist");
        return products[_productId];
    }//getProduct

    // We create the getShipment function. Every user can see information of the shipments UP UNTIL their authorization stage.
    // Product User: can see only OPEN shipments from Supply to Factory.
    // Factory User: can see all the shipments UP TO OPEN shipments with destination "Store"
    // Store User: can see all the shipments in the coffee supply chain.

    function getShipment(uint _transfer_id) public view returns(Shipment memory){
        require (userCheck[msg.sender], "Only Product User, Factory User or Store User can call this function." );
        require (shipments[_transfer_id].transfer_id == _transfer_id, "Transfer ID doesn't exist");
        bool authorized = false;
        if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Supply Manager"))) {
            if (keccak256(bytes(shipments[_transfer_id].origin)) == keccak256(bytes("Supply")) && keccak256(bytes(shipments[_transfer_id].destination)) == keccak256(bytes("Factory")) && shipments[_transfer_id].delivered == false){
                authorized = true; //Supply Manager is authorized to see the shipments he sent to factory which are still not delivered

            }
        }
        else if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Factory Manager"))){
            if (keccak256(bytes(shipments[_transfer_id].origin)) == keccak256(bytes("Supply")) && keccak256(bytes(shipments[_transfer_id].destination)) == keccak256(bytes("Factory"))){
                authorized = true; 
            } else if (keccak256(bytes(shipments[_transfer_id].origin)) == keccak256(bytes("Factory")) && keccak256(bytes(shipments[_transfer_id].destination)) == keccak256(bytes("Store")) && shipments[_transfer_id].delivered == false ) {
                authorized = true; // Factory Manager is authorized to view up to the shipments that he sent to store and are not delivered yet.
            }
        }
        else if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Store Manager"))) {
                authorized = true; //Store Manager is authorized to see all the shipments made.
            }
        require (authorized, "Not authorized for this action");
        return shipments[_transfer_id];
    }//getShipment

    //Create function IsToShelf, where the Store User can update the variable shelf to true, if the product has arrived to store.

    function IsToShelf(uint _productId) public {
        require(users[msg.sender].role_id == 3,"Not Authorized for this action");
        require(keccak256(abi.encodePacked(products[_productId].stage)) == keccak256(abi.encodePacked("Store")), "Product hasn't arrived to Store");
        products[_productId].shelf = true;
    }//IsToShelf
    
    //Create a function CustomerProductView where anyone (even a simple customer) with the id of the product can view some specific information of the product
    //ONLY in case that product has arrived to the store,so all the information of the product stays within the food supply workers , until the product is ready for B2C sales.
    //In this way, when a random person tries(by guessing random product IDs) to view info about a product that hasn't arrived to store shelves, the system will "fool" them and tell them that the product doesn't exist.
    //So, for a 3rd party the product exists ONLY and ONLY IF they are able to buy it.

    function CustomerProductView(uint _productId) public view returns(string memory, string memory, string memory, string memory){
        require(products[_productId].product_id == _productId," Product doesn't exist ");
        require(products[_productId].shelf == true,"Product doesn't exist");
        return (products[_productId].product_name, products[_productId].production_date, products[_productId].expiration_Date,products[_productId].product_region );
    }//CustomerProductView


    //Create a function that Factory or Store Manager can view the products that they are about to receive.
    function CheckReceipts()public view returns(ProductInfo[] memory){
        require(userCheck[msg.sender], "Not Authorized");
        require(users[msg.sender].role_id != 1, "Not Authorized");
        ProductInfo[] memory transferProducts = new ProductInfo[](ProductCount); // create an array that will contain the product IDs that the user is about to receive
        uint counter = 0;
        uint length = 0;
        if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Factory Manager"))){
            for (uint i = 1; i <= ProductCount; i++){
                if (keccak256(bytes(products[i].stage)) == keccak256(bytes("Transfering to Factory"))) {
                    transferProducts[counter] =ProductInfo({
                        productId: products[i].product_id,
                        productName: products[i].product_name,
                        productRegion: products[i].product_region
                        });
                    counter++;
                    length++;
                }
            }
        }else if(keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Store Manager"))){
            for (uint i = 1; i <= ProductCount; i++){
                if (keccak256(bytes(products[i].stage)) == keccak256(bytes("Delivering to Store"))) {
                    transferProducts[counter] = ProductInfo({
                        productId: products[i].product_id,
                        productName: products[i].product_name,
                        productRegion: products[i].product_region
                        });
                    counter++;
                    length++;
                }
            }
        }
        require(length > 0, "No product to receive");
        //Now create the final list, so for example if we have 10 products and only 1 is about to be received, the returned list will have length = 1
        uint j = 0;
        ProductInfo[] memory result = new ProductInfo[](length);
        for (uint i = 0; i<=length -1; i++){ 
                result[j] = transferProducts[i];
                j++;
        }

        return(result);
    }//CheckReceipts

    //Create a function that each manager will call when they finally receive the product. When it is called, the "stage" of the product will automatically be updated and the _date becomes the real arrival date.

    function ReceiveProduct(uint _productId, string memory _date) public{
        require(userCheck[msg.sender], "Not Authorized");
        require(users[msg.sender].role_id != 1, "Not Authorized");
        require(products[_productId].product_id == _productId," Product doesn't exist ");
        if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Factory Manager"))){
            if (keccak256(bytes(products[_productId].stage)) == keccak256(bytes("Transfering to Factory")) ){
                products[_productId].stage = "Factory";
            }
        }else if (keccak256(bytes(users[msg.sender].role)) == keccak256(bytes("Store Manager"))){
            if (keccak256(bytes(products[_productId].stage)) == keccak256(bytes("Delivering to Store")) ){
                products[_productId].stage = "Store";
            }
        }
        //Get the ID of the last shipment associated with the received product
        uint shipmentId = products[_productId].ship_product[products[_productId].ship_product.length - 1];
        
        //Set the delivered flag of the shipment to true
        shipments[shipmentId].delivered = true;
        shipments[shipmentId].arrival_date = _date;
    }//ReceiveProduct

    //Lastly create a function that only Store Manager can call, which returns all the products that are ready for sale.
    //Every product in this list is already proven that has started from Supply , moved to Factory and lastly transfered to Store
    function getShelfProducts() public view returns(ProductInfo[] memory){
        require(userCheck[msg.sender], "Not Authorized");
        require(users[msg.sender].role_id == 3, "Not Authorized");

        uint length = 0;

        //Count how many products are on the store shelves
        for (uint i = 1; i <= ProductCount; i++) {
            if (products[i].shelf == true) {
           length++;
            }
        }
        require(length >0, "No products on the shelves");
        ProductInfo [] memory result = new ProductInfo[](length);
        uint index = 0;
        for (uint i = 1; i <= ProductCount; i++) {
            if (products[i].shelf == true) {
            result[index] = ProductInfo({
                productId: products[i].product_id,
                productName: products[i].product_name,
                productRegion: products[i].product_region
            });
            index ++;
            }
        }
        return result;
    }//getShelfPrododucts
}//contract

