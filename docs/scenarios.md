# Adevrsarial scenario model

## Resiliency 

### Fault injecton
Action:
- Inject network latency (solve with a MITM proxy)
  - for a single node in a chain
  - for a single chain 
  - for multiple chains
- Transaction lag / finality manipulation 
  - flood a chain with transactions
  - create patterns for transaction distribution
- Machine state manipulation
  - shutdown
  - crash
  - block (/ unblock)
  - OOM


## Malicious actors
Detection against dishonesty :: L2 chain will detect improper transactions that are trying to claim L1 funds.

How to inject attacks:

**smart contracts:** 
- dApps
- Oracle manipulation 
- Frontrunning
- fuzzing 

**In the future: (perhaps a bit solidity oriented)**
- Randomness vulnerabilities
- Replay attacks
- Flash Loans & Flask Swaps
- Unchecked return value
- DAO / Governance
- Call / Delegatecall Attacks

**Network attacks** 
- avalanche 
  - https://github.com/tse-group/pos-ghost-attack
  - https://arxiv.org/pdf/2203.01315.pdf 
- DoS (Denial of service)


Map to DASP top 10? 
https://dasp.co/

1. Reentrancy
2. Access Control
3. Arithmetic
4. Unchecked Low Level Calls
5. Denial of Services
6. Bad Randomness
7. Front Running
8. Time Manipulation
9. Short Addresses
10. Unknown Unknowns