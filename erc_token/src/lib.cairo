pub mod errors;
pub mod interfaces;

#[starknet::contract]
pub mod RestrictedToken {
    use crate::errors::Errors;
    use crate::interfaces::{IERC20, IRestrictedToken};
    use core::num::traits::Zero;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    const MAX_LIMIT: u256 = 10000;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        transfer_limit: u256,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map::<ContractAddress, u256>,
        allowances: Map::<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        TransferLimitUpdated: TransferLimitUpdated,
        AdminBurn: AdminBurn,
        ApprovalRevoked: ApprovalRevoked,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Transfer {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Approval {
        pub owner: ContractAddress,
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct TransferLimitUpdated {
        pub old_limit: u256,
        pub new_limit: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct AdminBurn {
        pub account: ContractAddress,
        pub amount: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct ApprovalRevoked {
        pub owner: ContractAddress,
        pub spender: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        assert(!owner.is_zero(), Errors::ZERO_OWNER);
        assert(!recipient.is_zero(), Errors::ZERO_RECIPIENT);

        self.owner.write(owner);
        self.transfer_limit.write(MAX_LIMIT);
        self.name.write('Dave');
        self.symbol.write('DAVE');
        self.decimals.write(18);

        if initial_supply != Zero::zero() {
            self.mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl IERC20Impl of IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let caller = get_caller_address();
            self.spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, self.allowances.read((caller, spender)) + added_value);
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256,
        ) {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((caller, spender));
            assert(current_allowance >= subtracted_value, Errors::INSUFFICIENT_ALLOWANCE);
            self.approve_helper(caller, spender, current_allowance - subtracted_value);
        }
    }

    #[abi(embed_v0)]
    impl RestrictedTokenImpl of IRestrictedToken<ContractState> {
        fn get_transfer_limit(self: @ContractState) -> u256 {
            self.transfer_limit.read()
        }

        fn set_transfer_limit(ref self: ContractState, new_limit: u256) {
            self.assert_only_owner();
            assert(new_limit != Zero::zero(), Errors::INVALID_LIMIT);

            let old_limit = self.transfer_limit.read();
            self.transfer_limit.write(new_limit);
            self.emit(TransferLimitUpdated { old_limit, new_limit });
        }

        fn admin_burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.assert_only_owner();
            assert(!account.is_zero(), Errors::ZERO_ACCOUNT);
            assert(amount != Zero::zero(), Errors::ZERO_AMOUNT);
            self.burn(account, amount);
            self.emit(AdminBurn { account, amount });
        }

        fn revoke(ref self: ContractState, spender: ContractAddress) -> bool {
            assert(!spender.is_zero(), Errors::ZERO_SPENDER);

            let owner = get_caller_address();
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance == Zero::zero() {
                return false;
            }

            self.approve_helper(owner, spender, Zero::zero());
            self.emit(ApprovalRevoked { owner, spender });
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
        }

        fn _transfer(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!recipient.is_zero(), Errors::TRANSFER_TO_ZERO);
            assert(amount <= self.transfer_limit.read(), Errors::TRANSFER_LIMIT_EXCEEDED);

            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            self.balances.write(sender, sender_balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            assert(current_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
            self.allowances.write((owner, spender), current_allowance - amount);
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            assert(!owner.is_zero(), Errors::ZERO_ACCOUNT);
            assert(!spender.is_zero(), Errors::APPROVE_TO_ZERO);
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), Errors::MINT_TO_ZERO);
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self
                .emit(
                    Event::Transfer(
                        Transfer { from: Zero::zero(), to: recipient, value: amount },
                    ),
                );
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            let account_balance = self.balances.read(account);
            assert(account_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            self.balances.write(account, account_balance - amount);
            self.total_supply.write(self.total_supply.read() - amount);
            self
                .emit(
                    Event::Transfer(
                        Transfer { from: account, to: Zero::zero(), value: amount },
                    ),
                );
        }
    }
}
