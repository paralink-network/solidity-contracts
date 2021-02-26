// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/ParalinkOracle.sol";

pragma solidity 0.6.12;

contract Lottery is Ownable {
    using SafeMath for uint256;
    using Address for address;

    enum LOTTERY_STATE {OPEN, CLOSED, CALCULATING_WINNER}
    LOTTERY_STATE public lotteryState;

    // QmSGAgkrcCaLsfNrSmPEtPpZD52QanbVWYvr7XGNgUuWSb
    bytes32 ipfsHash = 0x3a48bd0b7321ed961ebf97d481fb3fc5383cdfaa6155c0256dc7f59741db55d0;
    uint256 public constant EXPIRY_TIME = 1 hours;
    uint256 public constant MINIMUM_ENTRY_FEE = 0.005 ether;

    ParalinkOracle oracle;
    address payable[] public participants;
    uint256 public lotteryId;
    uint256 public validUntil;

    event LotteryWinner(uint256 lotteryId, address winner);

    constructor(address paralinkOracle) public Ownable() {
        oracle = ParalinkOracle(paralinkOracle);
        lotteryId = 1;
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function startLottery() public onlyOwner {
        require(
            lotteryState == LOTTERY_STATE.CLOSED,
            "can't start a new lottery yet"
        );
        lotteryState = LOTTERY_STATE.OPEN;
        validUntil = now + EXPIRY_TIME;
    }

    function participate() public payable {
        assert(msg.value == MINIMUM_ENTRY_FEE);
        assert(lotteryState == LOTTERY_STATE.OPEN);
        assert(now <= validUntil);
        participants.push(msg.sender);
    }

    function pickWinner() public payable onlyOwner {
        assert(lotteryState == LOTTERY_STATE.OPEN);
        assert(now > validUntil);

        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        lotteryId = lotteryId + 1;

        // Start and oracle request
        bytes4 callbackFunctionId = bytes4(
            keccak256("fulfillRandomRequest(bytes32)")
        );
        oracle.request{value: msg.value}(
            ipfsHash,
            msg.value,
            msg.sender,
            address(this),
            callbackFunctionId,
            lotteryId,
            ""
        );
    }

    function fulfillRandomRequest(bytes32 _bigRandomNumber) public onlyOracle {
        require(
            lotteryState == LOTTERY_STATE.CALCULATING_WINNER,
            "No result to submit."
        );
        uint256 randomNumber = uint256(_bigRandomNumber);
        require(randomNumber > 0, "random-not-found");

        uint256 index = randomNumber % participants.length;
        participants[index].transfer(address(this).balance);
        emit LotteryWinner(lotteryId - 1, participants[index]);

        participants = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function getParticipants() public view returns (address payable[] memory) {
        return participants;
    }

    modifier onlyOracle() {
        require(msg.sender == address(oracle));
        _;
    }
}
