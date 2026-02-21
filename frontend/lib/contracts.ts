export const CONTRACTS = {
  OICDTreasury: process.env.NEXT_PUBLIC_OICD_TREASURY_ADDRESS as `0x${string}`,
  TwoDIBondTracker: process.env.NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS as `0x${string}`,
  DarkPool: process.env.NEXT_PUBLIC_DARK_POOL_ADDRESS as `0x${string}`,
  FractionalReserveBanking: process.env.NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS as `0x${string}`,
  ForexReservesTracker: process.env.NEXT_PUBLIC_FOREX_RESERVES_ADDRESS as `0x${string}`,
  SovereignInvestmentDAO: process.env.NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS as `0x${string}`,
  GovernmentSecuritiesSettlement: process.env.NEXT_PUBLIC_GOV_SECURITIES_ADDRESS as `0x${string}`,
  DigitalTradeBlocks: process.env.NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS as `0x${string}`,
  OZFParliament: process.env.NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS as `0x${string}`,
  ObsidianCapital: process.env.NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS as `0x${string}`,
  ArmsTradeCompliance: process.env.NEXT_PUBLIC_ARMS_TRADE_ADDRESS as `0x${string}`,
  InfrastructureAssets: process.env.NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS as `0x${string}`,
  PrimeBrokerage: process.env.NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS as `0x${string}`,
  LiquidityAsAService: process.env.NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS as `0x${string}`,
  SpecialEconomicZone: process.env.NEXT_PUBLIC_SEZ_ADDRESS as `0x${string}`,
  OGRBlacklist: process.env.NEXT_PUBLIC_OGR_BLACKLIST_ADDRESS as `0x${string}`,
  InviteManager: process.env.NEXT_PUBLIC_INVITE_MANAGER_ADDRESS as `0x${string}`,
  PriceOracleAggregator: process.env.NEXT_PUBLIC_PRICE_ORACLE_ADDRESS as `0x${string}`,
  UniversalAMM: process.env.NEXT_PUBLIC_UNIVERSAL_AMM_ADDRESS as `0x${string}`,
  // Phase 2C
  SovereignDEX: process.env.NEXT_PUBLIC_SOVEREIGN_DEX_ADDRESS as `0x${string}`,
  BondAuctionHouse: process.env.NEXT_PUBLIC_BOND_AUCTION_ADDRESS as `0x${string}`,
  PublicBrokerRegistry: process.env.NEXT_PUBLIC_BROKER_REGISTRY_ADDRESS as `0x${string}`,
  HFTEngine: process.env.NEXT_PUBLIC_HFT_ENGINE_ADDRESS as `0x${string}`,
  // Phase 3
  AVSPlatform: process.env.NEXT_PUBLIC_AVS_PLATFORM_ADDRESS as `0x${string}`,
  OTDToken: process.env.NEXT_PUBLIC_OTD_TOKEN_ADDRESS as `0x${string}`,
  OrionScore: process.env.NEXT_PUBLIC_ORION_SCORE_ADDRESS as `0x${string}`,
  FreeTradeRegistry: process.env.NEXT_PUBLIC_FREE_TRADE_REGISTRY_ADDRESS as `0x${string}`,
  ICFLending: process.env.NEXT_PUBLIC_ICF_LENDING_ADDRESS as `0x${string}`,
  PreAllocation: process.env.NEXT_PUBLIC_PRE_ALLOCATION_ADDRESS as `0x${string}`,
  JobsBoard: process.env.NEXT_PUBLIC_JOBS_BOARD_ADDRESS as `0x${string}`,
  // Phase 4
  DigitalTradeExchange: process.env.NEXT_PUBLIC_DTX_ADDRESS as `0x${string}`,
  DCMMarketCharter: process.env.NEXT_PUBLIC_DCM_CHARTER_ADDRESS as `0x${string}`,
};

export const CURRENCIES = {
  USD: 1, EUR: 2, GBP: 3, JPY: 4, CHF: 5, CNY: 6, AUD: 7, CAD: 8, OTD: 9, OICD: 10,
  RUB: 11, IDR: 12, MMK: 13, THB: 14, SGD: 15, EGP: 16, LYD: 17, LBP: 18, ILS: 19,
  JOD: 20, BAM: 21, SYP: 22, ALL: 23, BRL: 24, GEL: 25, DZD: 26, MAD: 27, KRW: 28,
  AMD: 29, NGN: 30, INR: 31, CLP: 32, ARS: 33, ZAR: 34, TND: 35, COP: 36, VES: 37,
  BOB: 38, MXN: 39, SAR: 40, QAR: 41, KWD: 42, OMR: 43, YER: 44, IQD: 45, IRR: 46,
  // New currencies
  AOA: 47, PLN: 48, HUF: 49, CZK: 50, RSD: 51, TRY: 52, BDT: 53, LKR: 54, UZS: 55,
  KZT: 56, TJS: 57, TMT: 58, AZN: 59, HKD: 60, MYR: 61,
} as const;

export const CURRENCY_NAMES: { [key: number]: string } = {
  1: 'USD', 2: 'EUR', 3: 'GBP', 4: 'JPY', 5: 'CHF', 6: 'CNY', 7: 'AUD', 8: 'CAD', 9: 'OTD', 10: 'OICD',
  11: 'RUB', 12: 'IDR', 13: 'MMK', 14: 'THB', 15: 'SGD', 16: 'EGP', 17: 'LYD', 18: 'LBP', 19: 'ILS',
  20: 'JOD', 21: 'BAM', 22: 'SYP', 23: 'ALL', 24: 'BRL', 25: 'GEL', 26: 'DZD', 27: 'MAD', 28: 'KRW',
  29: 'AMD', 30: 'NGN', 31: 'INR', 32: 'CLP', 33: 'ARS', 34: 'ZAR', 35: 'TND', 36: 'COP', 37: 'VES',
  38: 'BOB', 39: 'MXN', 40: 'SAR', 41: 'QAR', 42: 'KWD', 43: 'OMR', 44: 'YER', 45: 'IQD', 46: 'IRR',
  // New currencies - Angola, Poland, Hungary, Czech Republic, Serbia, Turkey, Bangladesh, Sri Lanka,
  // Uzbekistan, Kazakhstan, Tajikistan, Turkmenistan, Azerbaijan, Hong Kong, Malaysia
  47: 'AOA', 48: 'PLN', 49: 'HUF', 50: 'CZK', 51: 'RSD', 52: 'TRY', 53: 'BDT', 54: 'LKR', 55: 'UZS',
  56: 'KZT', 57: 'TJS', 58: 'TMT', 59: 'AZN', 60: 'HKD', 61: 'MYR',
};

export const MINISTRY_TYPES = {
  Treasury: 0,
  Finance: 1,
  Infrastructure: 2,
  Trade: 3,
  Defense: 4,
  Energy: 5,
  Technology: 6,
} as const;

export const PROPOSAL_CATEGORIES = {
  Treasury: 0,
  Infrastructure: 1,
  Policy: 2,
  Emergency: 3,
  Upgrade: 4,
  Parameter: 5,
  Ministry: 6,
} as const;

export const BOND_TYPES = {
  Infrastructure: 0,
  Green: 1,
  Social: 2,
  Strategic: 3,
  Emergency: 4,
} as const;

export const DERIVATIVE_TYPES = {
  Futures: 0,
  Options: 1,
  Swaps: 2,
  ForwardRate: 3,
  CreditDefault: 4,
} as const;
