export const CONTRACTS = {
  OICDTreasury: process.env.NEXT_PUBLIC_OICD_TREASURY_ADDRESS as `0x${string}`,
  TwoDIBondTracker: process.env.NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS as `0x${string}`,
  DarkPool: process.env.NEXT_PUBLIC_DARK_POOL_ADDRESS as `0x${string}`,
  CentralizedExchange: process.env.NEXT_PUBLIC_CEX_ADDRESS as `0x${string}`,
  IBANBankingSystem: process.env.NEXT_PUBLIC_IBAN_BANKING_ADDRESS as `0x${string}`,
  FractionalReserveBanking: process.env.NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS as `0x${string}`,
  ForexReservesTracker: process.env.NEXT_PUBLIC_FOREX_RESERVES_ADDRESS as `0x${string}`,
  SovereignInvestmentDAO: process.env.NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS as `0x${string}`,
  DebtSecuritiesIssuance: process.env.NEXT_PUBLIC_DEBT_SECURITIES_ADDRESS as `0x${string}`,
  InfrastructureBonds: process.env.NEXT_PUBLIC_INFRASTRUCTURE_BONDS_ADDRESS as `0x${string}`,
};

export const CURRENCIES = {
  USD: 0, EUR: 1, GBP: 2, JPY: 3, CHF: 4, CAD: 5, AUD: 6, CNY: 7, OTD: 8, OICD: 9,
  RUB: 10, IDR: 11, MMK: 12, THB: 13, SGD: 14, EGP: 15, LYD: 16, LBP: 17, ILS: 18,
  JOD: 19, BAM: 20, SYP: 21, ALL: 22, BRL: 23, GEL: 24, DZD: 25, MAD: 26, KRW: 27,
  AMD: 28, NGN: 29, INR: 30, CLP: 31, ARS: 32, ZAR: 33, TND: 34, COP: 35, VES: 36,
  BOB: 37, MXN: 38, SAR: 39, QAR: 40, KWD: 41, OMR: 42, YER: 43, IQD: 44, IRR: 45,
} as const;

export const CURRENCY_NAMES: { [key: number]: string } = {
  0: 'USD', 1: 'EUR', 2: 'GBP', 3: 'JPY', 4: 'CHF', 5: 'CAD', 6: 'AUD', 7: 'CNY', 8: 'OTD', 9: 'OICD',
  10: 'RUB', 11: 'IDR', 12: 'MMK', 13: 'THB', 14: 'SGD', 15: 'EGP', 16: 'LYD', 17: 'LBP', 18: 'ILS',
  19: 'JOD', 20: 'BAM', 21: 'SYP', 22: 'ALL', 23: 'BRL', 24: 'GEL', 25: 'DZD', 26: 'MAD', 27: 'KRW',
  28: 'AMD', 29: 'NGN', 30: 'INR', 31: 'CLP', 32: 'ARS', 33: 'ZAR', 34: 'TND', 35: 'COP', 36: 'VES',
  37: 'BOB', 38: 'MXN', 39: 'SAR', 40: 'QAR', 41: 'KWD', 42: 'OMR', 43: 'YER', 44: 'IQD', 45: 'IRR',
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
