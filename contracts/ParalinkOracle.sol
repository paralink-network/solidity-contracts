import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.6.12;

contract ParalinkOracle is Ownable {
    using SafeMath for uint256;
    using Address for address;

    uint256 public constant EXPIRY_TIME = 5 minutes;
    uint256 private constant MINIMUM_CALLBACK_GAS_LIMIT = 400_000;

    mapping(address => bool) private authorizedNodes;
    mapping(bytes32 => bytes32) private commitments;

    uint256 public minimumFee = 500_000;
    uint256 public withdrawableBalance;

    event Request(
        bytes32 indexed ipfsHash,
        address indexed requester,
        bytes32 indexed requestId,
        uint256 fee,
        address callbackAddress,
        bytes4 callbackFunctionId,
        uint256 expiration,
        bytes data
    );

    event RequestCanceled(bytes32 indexed requestId);

    constructor() public Ownable() {}

    function request(
        bytes32 _ipfsHash,
        uint256 _fee,
        address _sender,
        address _callbackAddress,
        bytes4 _callbackFunctionId,
        uint256 _nonce,
        bytes memory _data
    ) public payable {
        require(_fee == msg.value, "_fee must equal to msg.value");
        require(_fee >= minimumFee, "Must send more than min fee.");

        bytes32 requestId = keccak256(abi.encodePacked(_sender, _nonce));
        require(commitments[requestId] == 0, "Must use a unique ID");
        uint256 expiration = now.add(EXPIRY_TIME);

        commitments[requestId] = keccak256(
            abi.encodePacked(
                _fee,
                _callbackAddress,
                _callbackFunctionId,
                expiration
            )
        );

        emit Request(
            _ipfsHash,
            _sender,
            requestId,
            _fee,
            _callbackAddress,
            _callbackFunctionId,
            expiration,
            _data
        );
    }

    function cancelRequest(
        uint256 _fee,
        bytes32 _requestId,
        bytes4 _callbackFunc,
        uint256 _expiration
    ) external {
        bytes32 paramsHash = keccak256(
            abi.encodePacked(_fee, msg.sender, _callbackFunc, _expiration)
        );
        require(
            paramsHash == commitments[_requestId],
            "Params do not match request ID"
        );
        require(_expiration <= now, "Request is not expired");

        delete commitments[_requestId];
        emit RequestCanceled(_requestId);

        msg.sender.transfer(_fee);
    }

    function fulfillRequest(
        bytes32 _requestId,
        uint256 _fee,
        address _callbackAddress,
        bytes4 _callbackFunctionId,
        uint256 _expiration,
        bytes32 _data
    ) external onlyAuthorizedNode returns (bool) {
        require(commitments[_requestId] != 0, "Must have a valid requestId");
        bytes32 paramsHash = keccak256(
            abi.encodePacked(
                _fee,
                _callbackAddress,
                _callbackFunctionId,
                _expiration
            )
        );
        require(
            commitments[_requestId] == paramsHash,
            "Params do not match request ID"
        );
        withdrawableBalance = withdrawableBalance.add(_fee);
        delete commitments[_requestId];

        require(
            gasleft() >= MINIMUM_CALLBACK_GAS_LIMIT,
            "Must provide enough callback gas"
        );
        (bool success, ) = _callbackAddress.call(
            abi.encodePacked(_callbackFunctionId, _data)
        );

        return success;
    }

    function withdraw(address _recipient, uint256 _amount) external onlyOwner {
        require(
            withdrawableBalance >= _amount,
            "Amount requested is greater than withdrawable balance"
        );
        withdrawableBalance = withdrawableBalance.sub(_amount);

        payable(_recipient).transfer(_amount);
    }

    modifier onlyAuthorizedNode() {
        require(
            authorizedNodes[msg.sender] || msg.sender == owner(),
            "Invalid permissions."
        );
        _;
    }

    function setAuthorizedNode(address _node, bool _allowed)
        external
        onlyOwner
    {
        authorizedNodes[_node] = _allowed;
    }

    function setMinimumFee(uint256 _newFee) external onlyOwner {
        minimumFee = _newFee;
    }
}
