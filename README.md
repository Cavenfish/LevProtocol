# Leverage Bot/Protocol 

This is going to initially be a bot that manages leverage positions in Tranquil.
Eventually, I want to implement smart contracts that mnanage the positions.

## Concept

### Bull Tokens

1)Deposit collateral token in Tranquil
2)Borrow stable coins from Tranquil
3)Buy leverage token
3)Deposit leverage token in Tranquil
4)Repeat (2), (3) and (4) until desired leverage is reached

### Bear Tokens

This will be similar to Bull tokens, but it will borrow the
shorted token, and sell for stablecoins (which will be 
deposited in Tranquil)
