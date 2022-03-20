// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library MarketErrors {
    error Market_ItemNotFound();
    error Market_PositionNotFound();
    error Market_PositionWrongState();
    error Market_NotLastMarketVersion();
    error Market_OnlyOldMarketCall();
    error Market_InvalidFeeValue();
    error Market_InvalidFeeType();
    error Market_NoReefToBeClaimed();
    error Market_AddressBalanceTooLow();
    error Market_ItemAlreadyExists();
    error Market_ItemAlreadyRegistered();
    error Market_PriceZero();
    error Market_AmountZero();
    error Market_AmountTooLarge();
    error Market_InvalidValueSent();
    error Market_OnlySellerCanUnlist();
    error Market_InvalidNumberMinutes();
    error Market_AuctionEnded();
    error Market_InvalidBidValue();
    error Market_DeadlineNotReached();
    error Market_RaffleEnded();
    error Market_LoanAmountZero();
    error Market_LoanAlreadyFunded();
    error Market_LoanNotFunded();
    error Market_OnlyLenderCanLiquidate();
    error Market_OnlyBorrowerCanUnlist();
}
