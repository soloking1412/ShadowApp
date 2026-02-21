// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title FreeTradeRegistry — OZF Global Trade Agreement Registry
/// @notice On-chain registry for Free Trade Agreements and Bills of Lading
///         issued by Samuel Global Market Xchange Inc. / OZF.
///         All trades priced in $OICD. Registered with WTO and OZF Foreign Investment Ledger.
///         Supports Incoterms 2020 (FOB, CIF, DDP, etc.)
contract FreeTradeRegistry is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    enum AgreementStatus { Draft, PendingSignature, Active, Completed, Terminated, Disputed }

    enum Incoterms {
        EXW, FCA, CPT, CIP, DAP, DPU, DDP,  // any transport
        FAS, FOB, CFR, CIF                    // sea/inland waterway
    }

    enum PaymentTerms { Prepayment, Net30, Net60, Net90, Escrow, OpenAccount }

    enum CommodityType {
        Lithium, RareEarth, Grains, Petroleum, NaturalGas,
        Gold, Copper, Iron, Diamonds, Timber, Coal, Uranium,
        AI_Tech, GreenEnergy, Blockchain, QuantumComputing,
        RenewableInfra, Pipelines, SmartGrids,
        Patents, TradeSecrets, Logistics,
        Other
    }

    struct BillOfLading {
        string  bolNumber;
        address exporter;
        string  consignee;
        string  notifyParty;
        string  vesselName;
        string  portOfLoading;
        string  portOfDischarge;
        CommodityType commodityType;
        string  goodsDescription;
        uint256 quantityUnits;
        uint256 weightKg;
        uint256 declaredValueOICD;  // 1e18 scaled
        Incoterms incoterms;
        PaymentTerms paymentTerms;
        uint256 issuedAt;
        bool    signed;
    }

    struct TradeAgreement {
        uint256 agreementId;
        address exporter;
        address importer;
        address broker;
        string  exporterCountry;
        string  importerCountry;
        string  brokerInstitution;
        CommodityType[] commodities;
        uint256 totalValueOICD;    // 1e18 scaled
        Incoterms incoterms;
        PaymentTerms paymentTerms;
        AgreementStatus status;
        uint256 createdAt;
        uint256 effectiveDate;
        uint256 expiryDate;
        uint256 bolId;            // attached Bill of Lading
        bool    exporterSigned;
        bool    importerSigned;
        bool    registeredWithWTO;
        bool    registeredWithOZF;
        string  wtoFilingRef;
        string  ozfFilingRef;
    }

    // -- Storage --
    uint256 public agreementCounter;
    uint256 public bolCounter;
    uint256 public totalTradeValueOICD;
    uint256 public totalActiveAgreements;

    mapping(uint256 => TradeAgreement) public agreements;
    mapping(uint256 => BillOfLading) public billsOfLading;
    mapping(address => uint256[]) public exporterAgreements;
    mapping(address => uint256[]) public importerAgreements;
    mapping(address => uint256[]) public brokerAgreements;
    mapping(address => bool) public authorizedBrokers;

    // -- Events --
    event AgreementCreated(uint256 indexed agreementId, address exporter, address importer, uint256 valueOICD);
    event AgreementSigned(uint256 indexed agreementId, address signer, bool fullyExecuted);
    event BillOfLadingIssued(uint256 indexed bolId, uint256 indexed agreementId, string bolNumber);
    event AgreementRegistered(uint256 indexed agreementId, bool wto, bool ozf, string ref);
    event AgreementStatusUpdated(uint256 indexed agreementId, AgreementStatus status);
    event BrokerAuthorized(address broker, bool status);
    event DisputeRaised(uint256 indexed agreementId, address raisedBy, string reason);

    modifier onlyBroker() {
        require(authorizedBrokers[msg.sender] || msg.sender == owner(), "Not authorized broker");
        _;
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    // -- Broker Management --

    function authorizeBroker(address broker, bool status) external onlyOwner {
        authorizedBrokers[broker] = status;
        emit BrokerAuthorized(broker, status);
    }

    // -- Trade Agreement --

    function createAgreement(
        address importer,
        address broker,
        string calldata exporterCountry,
        string calldata importerCountry,
        string calldata brokerInstitution,
        uint8[] calldata commodityTypes,
        uint256 totalValueOICD,
        uint8 incotermsChoice,
        uint8 paymentTermsChoice,
        uint256 effectiveDateTs,
        uint256 expiryDateTs
    ) external returns (uint256 agreementId) {
        require(importer != address(0), "Invalid importer");
        require(totalValueOICD > 0, "Value required");
        require(effectiveDateTs < expiryDateTs, "Invalid dates");

        agreementId = ++agreementCounter;

        CommodityType[] memory comms = new CommodityType[](commodityTypes.length);
        for (uint256 i = 0; i < commodityTypes.length; i++) {
            comms[i] = CommodityType(commodityTypes[i]);
        }

        agreements[agreementId] = TradeAgreement({
            agreementId: agreementId,
            exporter: msg.sender,
            importer: importer,
            broker: broker,
            exporterCountry: exporterCountry,
            importerCountry: importerCountry,
            brokerInstitution: brokerInstitution,
            commodities: comms,
            totalValueOICD: totalValueOICD,
            incoterms: Incoterms(incotermsChoice),
            paymentTerms: PaymentTerms(paymentTermsChoice),
            status: AgreementStatus.Draft,
            createdAt: block.timestamp,
            effectiveDate: effectiveDateTs,
            expiryDate: expiryDateTs,
            bolId: 0,
            exporterSigned: false,
            importerSigned: false,
            registeredWithWTO: false,
            registeredWithOZF: false,
            wtoFilingRef: "",
            ozfFilingRef: ""
        });

        exporterAgreements[msg.sender].push(agreementId);
        importerAgreements[importer].push(agreementId);
        if (broker != address(0)) {
            brokerAgreements[broker].push(agreementId);
        }

        emit AgreementCreated(agreementId, msg.sender, importer, totalValueOICD);
    }

    function signAgreement(uint256 agreementId) external {
        TradeAgreement storage a = agreements[agreementId];
        require(
            msg.sender == a.exporter || msg.sender == a.importer,
            "Not a party"
        );
        require(a.status == AgreementStatus.Draft || a.status == AgreementStatus.PendingSignature, "Invalid status");

        if (msg.sender == a.exporter) { a.exporterSigned = true; }
        if (msg.sender == a.importer) { a.importerSigned = true; }

        bool fullyExecuted = a.exporterSigned && a.importerSigned;
        if (fullyExecuted) {
            a.status = AgreementStatus.Active;
            totalActiveAgreements++;
            totalTradeValueOICD += a.totalValueOICD;
        } else {
            a.status = AgreementStatus.PendingSignature;
        }

        emit AgreementSigned(agreementId, msg.sender, fullyExecuted);
    }

    // -- Bill of Lading --

    function issueBillOfLading(
        uint256 agreementId,
        string calldata bolNumber,
        string calldata consignee,
        string calldata notifyParty,
        string calldata vesselName,
        string calldata portOfLoading,
        string calldata portOfDischarge,
        uint8 commodityType,
        string calldata goodsDescription,
        uint256 quantityUnits,
        uint256 weightKg,
        uint256 declaredValueOICD,
        uint8 incotermsChoice
    ) external returns (uint256 bolId) {
        TradeAgreement storage a = agreements[agreementId];
        require(msg.sender == a.exporter || msg.sender == owner(), "Only exporter");
        require(a.status == AgreementStatus.Active, "Agreement not active");

        bolId = ++bolCounter;
        billsOfLading[bolId] = BillOfLading({
            bolNumber: bolNumber,
            exporter: msg.sender,
            consignee: consignee,
            notifyParty: notifyParty,
            vesselName: vesselName,
            portOfLoading: portOfLoading,
            portOfDischarge: portOfDischarge,
            commodityType: CommodityType(commodityType),
            goodsDescription: goodsDescription,
            quantityUnits: quantityUnits,
            weightKg: weightKg,
            declaredValueOICD: declaredValueOICD,
            incoterms: Incoterms(incotermsChoice),
            paymentTerms: PaymentTerms(0),
            issuedAt: block.timestamp,
            signed: true
        });

        a.bolId = bolId;
        emit BillOfLadingIssued(bolId, agreementId, bolNumber);
    }

    // -- WTO / OZF Registration --

    function registerWithAuthorities(
        uint256 agreementId,
        bool withWTO,
        bool withOZF,
        string calldata filingRef
    ) external onlyOwner {
        TradeAgreement storage a = agreements[agreementId];
        require(a.status == AgreementStatus.Active, "Agreement not active");
        if (withWTO) { a.registeredWithWTO = true; a.wtoFilingRef = filingRef; }
        if (withOZF) { a.registeredWithOZF = true; a.ozfFilingRef = filingRef; }
        emit AgreementRegistered(agreementId, withWTO, withOZF, filingRef);
    }

    function completeAgreement(uint256 agreementId) external {
        TradeAgreement storage a = agreements[agreementId];
        require(msg.sender == a.exporter || msg.sender == a.importer || msg.sender == owner(), "Not a party");
        require(a.status == AgreementStatus.Active, "Not active");
        a.status = AgreementStatus.Completed;
        if (totalActiveAgreements > 0) totalActiveAgreements--;
        emit AgreementStatusUpdated(agreementId, AgreementStatus.Completed);
    }

    function raiseDispute(uint256 agreementId, string calldata reason) external {
        TradeAgreement storage a = agreements[agreementId];
        require(msg.sender == a.exporter || msg.sender == a.importer, "Not a party");
        a.status = AgreementStatus.Disputed;
        emit DisputeRaised(agreementId, msg.sender, reason);
    }

    // -- Views --

    function getAgreement(uint256 id) external view returns (TradeAgreement memory) {
        return agreements[id];
    }

    function getBOL(uint256 bolId) external view returns (BillOfLading memory) {
        return billsOfLading[bolId];
    }

    function getExporterAgreements(address e) external view returns (uint256[] memory) {
        return exporterAgreements[e];
    }

    function getImporterAgreements(address i) external view returns (uint256[] memory) {
        return importerAgreements[i];
    }

    function getBrokerAgreements(address b) external view returns (uint256[] memory) {
        return brokerAgreements[b];
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
