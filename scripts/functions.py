from brownie import network, config, accounts, MockV3Aggregator, Contract, VRFCoordinatorV2Mock

# Define mappings here 
contract_to_mock = {"eth_usd_price_feed": MockV3Aggregator}
dev_envs = {"development", "ganache-local"}
forked_local_envs = {"mainnet-fork-dev"}

def get_account(dev_envs: set, forked_local_envs, index=None, id=None):
    # Can define a function here
    # Here we have local ganache account
    # Or used environment variables
    # 3rd method - load from our ID

    if index:
        return accounts[index]

    if id:
        return accounts.load[id] 

    if network.show_active() in dev_envs or network.show_active() in forked_local_envs:
        return accounts[0] 

    return accounts.add(config["wallets"]["from_key"])




def get_contract(contract_name):
    """ This function will grab the contract addresses from the brownie config 
    if defined, otherwise it will deploy a mocked version of that contract and return.
        Args:
            contract_name (string)

        Returns:
            brownie.network.contract.ProjectContract: The most recently deployed version of this contract

    """
    # Get the contract type
    contract_type = contract_to_mock[contract_name]

    if network.show_active() in dev_envs:
        # For dev nets
        if len(contract_type) <= 0:
            # Checking how many MockV3 aggregators have been deployed
            # Now want to get that mock
            deploy_mocks()
        contract = contract_type[-1]

        # MockV3Aggregator[-1] aka the most recent version of it

    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        # address and ABI
        contract = Contract.from_abi(contract_type._name, contract_address, contract_type.abi)
        # All have an ABI attribute

    return contract



## Deploying a Mock
DECIMALS=8
INITIAL_VALUE=200000000000

def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    account=get_account(dev_envs, forked_local_envs)
    MockV3Aggregator.deploy(decimals, initial_value, {"from":account})
    VRFCoordinatorV2Mock.deploy(150, 150, {"from":account})
    print("Deployed!")


def fund_subscription(subId, amount=100_000_000_000_000_000):
    """
    Function to fund a subscription for the VRF Coordinator
    """
    vrf_coordinator = VRFCoordinatorV2Mock[-1]
    tx = vrf_coordinator.fundSubscription(subId, amount)
    tx.wait(1)
    print("Subscription Funded")


