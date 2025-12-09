// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RINRegistry - COMPLETE PRODUCTION VERSION
 * @notice Route Identification Number registry for trade routes with blockchain verification
 */
contract RINRegistry is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    bytes32 public constant CUSTOMS_ROLE = keccak256("CUSTOMS_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum RouteStatus {
        Proposed,
        Active,
        Suspended,
        Revoked,
        Expired
    }
    
    enum CargoType {
        General,
        Containerized,
        Bulk,
        LiquidBulk,
        Refrigerated,
        Hazardous,
        Livestock,
        Vehicles
    }
    
    enum TransportMode {
        Maritime,
        Air,
        Rail,
        Road,
        Multimodal
    }
    
    struct TradeRoute {
        string rin;
        address registrant;
        string originPort;
        string destinationPort;
        string[] transitPorts;
        TransportMode mode;
        CargoType[] allowedCargo;
        RouteStatus status;
        uint256 registrationDate;
        uint256 expiryDate;
        uint256 lastUsed;
        uint256 totalShipments;
        uint256 totalValue;
        bytes32 licenseHash;
        bool requiresInspection;
    }
    
    struct Shipment {
        uint256 shipmentId;
        string rin;
        address shipper;
        string vesselName;
        string cargoDescription;
        CargoType cargoType;
        uint256 cargoValue;
        uint256 weight;
        uint256 departureDate;
        uint256 arrivalDate;
        uint256 actualArrivalDate;
        bytes32 billOfLadingHash;
        bytes32 customsDeclarationHash;
        bool customsCleared;
        bool delivered;
    }
    
    struct CustomsClearance {
        uint256 clearanceId;
        uint256 shipmentId;
        address customsOfficer;
        uint256 clearanceDate;
        uint256 dutyPaid;
        uint256 taxPaid;
        bool approved;
        string remarks;
    }
    
    struct Insurance {
        uint256 insuranceId;
        uint256 shipmentId;
        address insurer;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startDate;
        uint256 endDate;
        bool active;
    }
    
    mapping(string => TradeRoute) public routes;
    mapping(uint256 => Shipment) public shipments;
    mapping(uint256 => CustomsClearance) public clearances;
    mapping(uint256 => Insurance) public insurances;
    mapping(string => uint256[]) public routeShipments;
    mapping(address => string[]) public registrantRoutes;
    
    string[] public allRINs;
    uint256 public shipmentCounter;
    uint256 public clearanceCounter;
    uint256 public insuranceCounter;
    
    uint256 public registrationFee;
    uint256 public renewalFee;
    uint256 public defaultValidityPeriod;
    
    event RouteRegistered(string indexed rin, address indexed registrant, TransportMode mode);
    event RouteActivated(string indexed rin);
    event RouteSuspended(string indexed rin, string reason);
    event RouteRevoked(string indexed rin);
    event ShipmentCreated(uint256 indexed shipmentId, string indexed rin, address indexed shipper);
    event CustomsCleared(uint256 indexed shipmentId, uint256 indexed clearanceId);
    event ShipmentDelivered(uint256 indexed shipmentId);
    event InsurancePurchased(uint256 indexed insuranceId, uint256 indexed shipmentId);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        uint256 _registrationFee,
        uint256 _validityPeriod
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
        _grantRole(CUSTOMS_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        registrationFee = _registrationFee;
        renewalFee = _registrationFee / 2;
        defaultValidityPeriod = _validityPeriod;
    }
    
    function registerRoute(
        string memory originPort,
        string memory destinationPort,
        string[] memory transitPorts,
        TransportMode mode,
        CargoType[] memory allowedCargo,
        uint256 validityPeriod,
        bytes32 licenseHash,
        bool requiresInspection
    ) external payable nonReentrant whenNotPaused returns (string memory) {
        require(msg.value >= registrationFee, "Insufficient fee");
        require(bytes(originPort).length > 0 && bytes(destinationPort).length > 0, "Invalid ports");
        
        // Generate RIN
        string memory rin = _generateRIN(originPort, destinationPort, mode);
        require(bytes(routes[rin].rin).length == 0, "Route already exists");
        
        routes[rin] = TradeRoute({
            rin: rin,
            registrant: msg.sender,
            originPort: originPort,
            destinationPort: destinationPort,
            transitPorts: transitPorts,
            mode: mode,
            allowedCargo: allowedCargo,
            status: RouteStatus.Proposed,
            registrationDate: block.timestamp,
            expiryDate: block.timestamp + (validityPeriod > 0 ? validityPeriod : defaultValidityPeriod),
            lastUsed: 0,
            totalShipments: 0,
            totalValue: 0,
            licenseHash: licenseHash,
            requiresInspection: requiresInspection
        });
        
        allRINs.push(rin);
        registrantRoutes[msg.sender].push(rin);
        
        emit RouteRegistered(rin, msg.sender, mode);
        
        return rin;
    }
    
    function _generateRIN(
        string memory origin,
        string memory destination,
        TransportMode mode
    ) internal view returns (string memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                origin,
                destination,
                mode,
                block.timestamp,
                msg.sender
            )
        );
        
        // Convert to alphanumeric RIN format: RIN-XXXXX-XXXXX
        return string(
            abi.encodePacked(
                "RIN-",
                _toHexString(uint256(hash) >> 128),
                "-",
                _toHexString(uint256(hash) & 0xFFFFFFFFFFFFFFFF)
            )
        );
    }
    
    function _toHexString(uint256 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(5);
        for (uint256 i = 5; i > 0; i--) {
            buffer[i - 1] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    function activateRoute(string memory rin) 
        external 
        onlyRole(REGISTRAR_ROLE) 
    {
        TradeRoute storage route = routes[rin];
        require(route.status == RouteStatus.Proposed, "Invalid status");
        
        route.status = RouteStatus.Active;
        
        emit RouteActivated(rin);
    }
    
    function createShipment(
        string memory rin,
        string memory vesselName,
        string memory cargoDescription,
        CargoType cargoType,
        uint256 cargoValue,
        uint256 weight,
        uint256 departureDate,
        uint256 estimatedArrival,
        bytes32 billOfLadingHash
    ) external nonReentrant whenNotPaused returns (uint256) {
        TradeRoute storage route = routes[rin];
        require(route.status == RouteStatus.Active, "Route not active");
        require(block.timestamp < route.expiryDate, "Route expired");
        require(_isCargoAllowed(route, cargoType), "Cargo type not allowed");
        
        uint256 shipmentId = ++shipmentCounter;
        
        shipments[shipmentId] = Shipment({
            shipmentId: shipmentId,
            rin: rin,
            shipper: msg.sender,
            vesselName: vesselName,
            cargoDescription: cargoDescription,
            cargoType: cargoType,
            cargoValue: cargoValue,
            weight: weight,
            departureDate: departureDate,
            arrivalDate: estimatedArrival,
            actualArrivalDate: 0,
            billOfLadingHash: billOfLadingHash,
            customsDeclarationHash: bytes32(0),
            customsCleared: false,
            delivered: false
        });
        
        routeShipments[rin].push(shipmentId);
        route.totalShipments++;
        route.totalValue += cargoValue;
        route.lastUsed = block.timestamp;
        
        emit ShipmentCreated(shipmentId, rin, msg.sender);
        
        return shipmentId;
    }
    
    function _isCargoAllowed(TradeRoute storage route, CargoType cargoType) 
        internal 
        view 
        returns (bool) 
    {
        for (uint256 i = 0; i < route.allowedCargo.length; i++) {
            if (route.allowedCargo[i] == cargoType) {
                return true;
            }
        }
        return false;
    }
    
    function processCustomsClearance(
        uint256 shipmentId,
        uint256 dutyPaid,
        uint256 taxPaid,
        bool approved,
        string memory remarks,
        bytes32 customsDeclarationHash
    ) external onlyRole(CUSTOMS_ROLE) returns (uint256) {
        Shipment storage shipment = shipments[shipmentId];
        require(!shipment.customsCleared, "Already cleared");
        
        uint256 clearanceId = ++clearanceCounter;
        
        clearances[clearanceId] = CustomsClearance({
            clearanceId: clearanceId,
            shipmentId: shipmentId,
            customsOfficer: msg.sender,
            clearanceDate: block.timestamp,
            dutyPaid: dutyPaid,
            taxPaid: taxPaid,
            approved: approved,
            remarks: remarks
        });
        
        if (approved) {
            shipment.customsCleared = true;
            shipment.customsDeclarationHash = customsDeclarationHash;
        }
        
        emit CustomsCleared(shipmentId, clearanceId);
        
        return clearanceId;
    }
    
    function purchaseInsurance(
        uint256 shipmentId,
        uint256 coverageAmount,
        uint256 duration
    ) external payable nonReentrant returns (uint256) {
        Shipment storage shipment = shipments[shipmentId];
        require(msg.sender == shipment.shipper, "Not shipper");
        require(coverageAmount > 0, "Invalid coverage");
        
        uint256 premium = _calculatePremium(shipment.cargoValue, coverageAmount, duration);
        require(msg.value >= premium, "Insufficient premium");
        
        uint256 insuranceId = ++insuranceCounter;
        
        insurances[insuranceId] = Insurance({
            insuranceId: insuranceId,
            shipmentId: shipmentId,
            insurer: msg.sender,
            coverageAmount: coverageAmount,
            premium: premium,
            startDate: block.timestamp,
            endDate: block.timestamp + duration,
            active: true
        });
        
        emit InsurancePurchased(insuranceId, shipmentId);
        
        return insuranceId;
    }
    
    function _calculatePremium(
        uint256 cargoValue,
        uint256 coverageAmount,
        uint256 duration
    ) internal pure returns (uint256) {
        // Simple premium calculation: 0.5% of coverage per 30 days
        uint256 durationInMonths = (duration + 29 days) / 30 days;
        return (coverageAmount * 50 * durationInMonths) / 10000;
    }
    
    function confirmDelivery(uint256 shipmentId) 
        external 
    {
        Shipment storage shipment = shipments[shipmentId];
        require(msg.sender == shipment.shipper, "Not shipper");
        require(shipment.customsCleared, "Customs not cleared");
        require(!shipment.delivered, "Already delivered");
        
        shipment.delivered = true;
        shipment.actualArrivalDate = block.timestamp;
        
        emit ShipmentDelivered(shipmentId);
    }
    
    function suspendRoute(string memory rin, string memory reason) 
        external 
        onlyRole(REGISTRAR_ROLE) 
    {
        TradeRoute storage route = routes[rin];
        require(route.status == RouteStatus.Active, "Not active");
        
        route.status = RouteStatus.Suspended;
        
        emit RouteSuspended(rin, reason);
    }
    
    function revokeRoute(string memory rin) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        TradeRoute storage route = routes[rin];
        
        route.status = RouteStatus.Revoked;
        
        emit RouteRevoked(rin);
    }
    
    function renewRoute(string memory rin, uint256 extensionPeriod) 
        external 
        payable 
        nonReentrant 
    {
        TradeRoute storage route = routes[rin];
        require(msg.sender == route.registrant, "Not registrant");
        require(msg.value >= renewalFee, "Insufficient fee");
        
        route.expiryDate += (extensionPeriod > 0 ? extensionPeriod : defaultValidityPeriod);
        
        if (route.status == RouteStatus.Expired) {
            route.status = RouteStatus.Active;
        }
    }
    
    function checkExpiredRoutes() external {
        for (uint256 i = 0; i < allRINs.length; i++) {
            TradeRoute storage route = routes[allRINs[i]];
            if (route.status == RouteStatus.Active && block.timestamp > route.expiryDate) {
                route.status = RouteStatus.Expired;
            }
        }
    }
    
    function setRegistrationFee(uint256 fee) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        registrationFee = fee;
    }
    
    function setRenewalFee(uint256 fee) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        renewalFee = fee;
    }
    
    function setDefaultValidityPeriod(uint256 period) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        defaultValidityPeriod = period;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getRoute(string memory rin) 
        external 
        view 
        returns (TradeRoute memory) 
    {
        return routes[rin];
    }
    
    function getShipment(uint256 shipmentId) 
        external 
        view 
        returns (Shipment memory) 
    {
        return shipments[shipmentId];
    }
    
    function getRouteShipments(string memory rin) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return routeShipments[rin];
    }
    
    function getRegistrantRoutes(address registrant) 
        external 
        view 
        returns (string[] memory) 
    {
        return registrantRoutes[registrant];
    }
    
    function getAllRINs() 
        external 
        view 
        returns (string[] memory) 
    {
        return allRINs;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    receive() external payable {}
}