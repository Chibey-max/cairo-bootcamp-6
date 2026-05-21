use erc_token::interfaces::{
    IERC20Dispatcher, IERC20DispatcherTrait, IRestrictedTokenDispatcher, IRestrictedTokenDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

const INITIAL_SUPPLY: u256 = 1_000_000;
const DEFAULT_LIMIT: u256 = 10_000;

fn addr(v: felt252) -> ContractAddress {
    v.try_into().unwrap()
}

fn deploy_token(
    owner: ContractAddress, initial_supply: u256, recipient: ContractAddress,
) -> (ContractAddress, IERC20Dispatcher, IRestrictedTokenDispatcher) {
    let contract = declare("RestrictedToken").unwrap().contract_class();
    let calldata = array![
        owner.into(), initial_supply.low.into(), initial_supply.high.into(), recipient.into(),
    ];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    (
        contract_address,
        IERC20Dispatcher { contract_address },
        IRestrictedTokenDispatcher { contract_address },
    )
}

#[test]
fn test_constructor_sets_metadata_supply_and_limit() {
    let owner = addr(0x111);
    let recipient = owner;
    let (_, erc20, restricted) = deploy_token(owner, INITIAL_SUPPLY, recipient);

    assert(erc20.get_name() == 'Dave', 'bad name');
    assert(erc20.get_symbol() == 'DAVE', 'bad symbol');
    assert(erc20.get_decimals() == 18, 'bad decimals');
    assert(erc20.get_total_supply() == INITIAL_SUPPLY, 'bad supply');
    assert(erc20.balance_of(recipient) == INITIAL_SUPPLY, 'bad recipient balance');
    assert(restricted.get_transfer_limit() == DEFAULT_LIMIT, 'bad initial limit');
}

#[test]
fn test_transfer_moves_balance() {
    let owner = addr(0x111);
    let recipient = addr(0x222);
    let (contract_address, erc20, _) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    erc20.transfer(recipient, 100);
    stop_cheat_caller_address(contract_address);

    assert(erc20.balance_of(owner) == INITIAL_SUPPLY - 100, 'owner balance mismatch');
    assert(erc20.balance_of(recipient) == 100, 'recipient balance mismatch');
}

#[test]
fn test_transfer_from_spends_allowance() {
    let owner = addr(0x111);
    let spender = addr(0x222);
    let recipient = addr(0x333);
    let (contract_address, erc20, _) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    erc20.approve(spender, 75);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, spender);
    erc20.transfer_from(owner, recipient, 50);
    stop_cheat_caller_address(contract_address);

    assert(erc20.balance_of(recipient) == 50, 'recipient not funded');
    assert(erc20.allowance(owner, spender) == 25, 'allowance not spent');
}

#[test]
fn test_set_transfer_limit_owner_success() {
    let owner = addr(0x111);
    let (contract_address, _, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    restricted.set_transfer_limit(5_000);
    stop_cheat_caller_address(contract_address);

    assert(restricted.get_transfer_limit() == 5_000, 'limit not updated');
}

#[test]
#[should_panic(expected: 'ONLY_OWNER')]
fn test_set_transfer_limit_non_owner_panics() {
    let owner = addr(0x111);
    let attacker = addr(0x999);
    let (contract_address, _, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, attacker);
    restricted.set_transfer_limit(5_000);
}

#[test]
#[should_panic]
fn test_transfer_over_limit_panics() {
    let owner = addr(0x111);
    let recipient = addr(0x222);
    let (contract_address, erc20, _) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    erc20.transfer(recipient, DEFAULT_LIMIT + 1);
}

#[test]
fn test_revoke_returns_false_when_no_allowance() {
    let owner = addr(0x111);
    let spender = addr(0x222);
    let (contract_address, _, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    let revoked = restricted.revoke(spender);
    stop_cheat_caller_address(contract_address);

    assert(!revoked, 'revoke should be false');
}

#[test]
fn test_revoke_clears_existing_allowance() {
    let owner = addr(0x111);
    let spender = addr(0x222);
    let (contract_address, erc20, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    erc20.approve(spender, 100);
    let revoked = restricted.revoke(spender);
    stop_cheat_caller_address(contract_address);

    assert(revoked, 'expected revoke true');
    assert(erc20.allowance(owner, spender) == 0, 'allowance not cleared');
}

#[test]
fn test_admin_burn_owner_reduces_supply_and_balance() {
    let owner = addr(0x111);
    let (contract_address, erc20, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, owner);
    restricted.admin_burn(owner, 1);
    stop_cheat_caller_address(contract_address);

    assert(erc20.get_total_supply() == INITIAL_SUPPLY - 1, 'supply not reduced');
    assert(erc20.balance_of(owner) == INITIAL_SUPPLY - 1, 'owner balance not reduced');
}

#[test]
#[should_panic(expected: 'ONLY_OWNER')]
fn test_admin_burn_non_owner_panics() {
    let owner = addr(0x111);
    let attacker = addr(0x999);
    let (contract_address, _, restricted) = deploy_token(owner, INITIAL_SUPPLY, owner);

    start_cheat_caller_address(contract_address, attacker);
    restricted.admin_burn(owner, 1);
}
