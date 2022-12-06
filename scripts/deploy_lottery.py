from scripts.functions import get_account, get_contract, get_account, fund_subscription
from brownie import Lottery, network, config
import time


dev_envs = {"development", "ganache-local"}
forked_local_envs = {"mainnet-fork-dev"}


def deploy_lottery():
    # Dont need to adjust for test or local
    account = get_account(dev_envs, forked_local_envs)
    lottery = Lottery.deploy(get_contract("eth_usd_price_feed").address, 3438, {
                             "from": account}, publish_source=config["networks"][network.show_active()].get("verify",False))

    print("Lottery Deployed!")

    pass

def start_lottery():

    # Get the account
    account = get_account(dev_envs, forked_local_envs)

    # Lottery will be the most recent deployment
    lottery = Lottery[-1]

    # Call the start function 
    starting_tx = lottery.startLottery({"from": account})
    starting_tx.wait(1)
    print("The lottery has started!")


def enter_lottery():
    # Get the account
    account = get_account(dev_envs, forked_local_envs)

    # Lottery will be the most recent deployment
    lottery = Lottery[-1]

    # Need to send a value with this 
    value = lottery.getEntranceFee() + 10000000 # add a little bit just to be on the safe side

    # Call the entere function 
    tx = lottery.enter({"from": account, "value" : value})
    tx.wait(1)
    print("You entered the lottery!")

def end_lottery():
    # Get the account
    account = get_account(dev_envs, forked_local_envs)

    # Lottery will be the most recent deployment
    lottery = Lottery[-1]

    # This function actually calls request randomness function
    # Fund the subscription if desired
    tx = fund_subscription(150)
    tx.wait(1)

    # Need to send a value with this 
    ending_tx = lottery.endLottery()
    ending_tx.wait(1)
    print("You ended the lottery! Calculating winner...")

    time.sleep(5)
    print(f"{lottery.recentWinner} is the winner!")

    
def main():
    deploy_lottery()
    start_lottery()
    enter_lottery()
    end_lottery()
