// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Blottery {
    uint256 public ticketID;
    address public owner;
    address[] public users;
    address[] winners;
    LotteryRules public rules;

    mapping(GameType => uint256) public gameBalances;
    mapping(address => TicketStatus[]) public playerStatuses;
    mapping(GameType => GameInfo) public gameInfos;

    event TicketPurchased(address indexed player, GameType game, uint256 ticketID, uint256[] selectedOptions);
    event GameResult(GameType game, uint256[] winningNumbers, address[] winners);

    struct LotteryRules {
        uint maxLottoNumbers;
        uint selectNumbers;
        uint startMoneyThreshold;
    }

    struct TicketStatus {
        bool used;
        GameType gamePlayed;
        uint256 paidFee;
        uint256[] randomWord;
        bool didWin;
        uint256 startDate;
        uint256 ticketId;
        address player;
        uint256 betAmount;
        uint256[] selectedOptions;
    }

    struct GameInfo {
        uint256 betAmount;
        uint256 duration;
        uint256 endDate;
    }
    enum GameType {
        COIN_FLIP,
        DICE_ROLL,
        LOTTO
    }

    constructor() {
        ticketID = 0;
        owner = msg.sender;

        setGameInfo(GameType.COIN_FLIP, 10 wei, 20 seconds);
        setGameInfo(GameType.DICE_ROLL, 20 wei, 20 seconds);
        setGameInfo(GameType.LOTTO, 50 wei, 50 seconds);
        setLottoRules(32, 6, 30 wei);
    }

    // START - Main Logic

    function buyTicket(GameType game, uint256[] memory selectedOptions) public payable validateCanBuyTicket(game, selectedOptions) {
        ticketID++;

        if (gameInfos[game].endDate < block.timestamp && canStartGame(game)) {
            gameInfos[game].endDate = block.timestamp + gameInfos[game].duration;
        }

        uint gamePrice = getGamePrice(game);

        gameBalances[game] += gamePrice; // maybe betAmount?(Games price?) or msg.value

        TicketStatus memory newGameStatus = TicketStatus({used: false, gamePlayed: game, paidFee: msg.value, betAmount: gamePrice, randomWord: new uint[](0), didWin: false, startDate: block.timestamp, ticketId: ticketID, player: msg.sender, selectedOptions: selectedOptions});

        addGameStatus(msg.sender, newGameStatus);

        emit TicketPurchased(msg.sender, game, ticketID, selectedOptions);
    }

    function conductGame(GameType game) public onlyOwner returns (uint256[] memory) {
        uint256[] memory winningNumbers;

        if (game == GameType.COIN_FLIP) {
            winningNumbers = flipCoin();
        } else if (game == GameType.DICE_ROLL) {
            winningNumbers = rollDice();
        } else if (game == GameType.LOTTO) {
            winningNumbers = lottoShuffle();
        }
        recordLotteryResults(game, winningNumbers);

        return winningNumbers;
    }

    function recordLotteryResults(GameType game, uint256[] memory winningNumbers) internal {
        for (uint256 i = 0; i < users.length; i++) {
            TicketStatus[] memory userTicketStatuses = playerStatuses[users[i]];

            for (uint256 j = 0; j < userTicketStatuses.length; j++) {
                if (userTicketStatuses[j].gamePlayed == game && !userTicketStatuses[j].used) {
                    bool didWin = false;

                    if (game == GameType.COIN_FLIP) {
                        didWin = winningNumbers[0] == userTicketStatuses[j].selectedOptions[0];
                    } else if (game == GameType.DICE_ROLL) {
                        didWin = winningNumbers[0] == userTicketStatuses[j].selectedOptions[0] && winningNumbers[1] == userTicketStatuses[j].selectedOptions[1];
                    } else if (game == GameType.LOTTO) {
                        didWin = areArraysEqual(winningNumbers, userTicketStatuses[j].selectedOptions);
                    }

                    if (didWin) {
                        winners.push(users[i]);
                    }

                    playerStatuses[users[i]][j].used = true;
                    playerStatuses[users[i]][j].randomWord = winningNumbers;
                    playerStatuses[users[i]][j].didWin = didWin;
                }
            }
        }

        if (winners.length > 0) {
            uint256 winnings = calculateWinningAmount(game, winners.length);

            for (uint256 i = 0; i < winners.length; i++) {
                // reentrance problem fixed
                address winner = winners[i];
                uint256 amountToTransfer = winnings;

                gameBalances[game] -= amountToTransfer;

                require(address(this).balance >= amountToTransfer, "Insufficient contract balance for transfer");
                (bool success, ) = payable(winner).call{value: amountToTransfer}("");
                require(success, "Transfer failed");
            }
        }

        // else no one won

        emit GameResult(game, winningNumbers, winners); // if player won 2 times, it will be in winners array 2 times, but in the end he should receive what he won anyways

        gameBalances[game] = 0; // reset this

        delete winners;
    }

    // END - Main Logic

    // START -- HELPER FUNCTIONS

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function canStartGame(GameType game) public view returns (bool) {
        return gameBalances[game] >= rules.startMoneyThreshold;
    }

    function calculateWinningAmount(GameType game, uint256 numberOfWinners) internal view returns (uint256) {
        uint256 totalBetAmount = gameBalances[game];

        uint256 winningAmountPerWinner = totalBetAmount / numberOfWinners;
        return winningAmountPerWinner / 2;
    }

    modifier validateCanBuyTicket(GameType game, uint256[] memory selectedOptions) {
        require(msg.value >= getGamePrice(game), "You do not have enough money to participate!");

        if (game == GameType.COIN_FLIP) {
            require(selectedOptions.length == 1, "Coin Flip requires exactly one option");
            require(selectedOptions[0] == 0 || selectedOptions[0] == 1, "Invalid option for Coin Flip");
        } else if (game == GameType.DICE_ROLL) {
            require(selectedOptions.length == 2, "Dice Roll requires exactly two options");
            require(selectedOptions[0] >= 1 && selectedOptions[0] <= 6, "Dice option out of range");
            require(selectedOptions[1] >= 1 && selectedOptions[1] <= 6, "Dice option out of range");
        } else if (game == GameType.LOTTO) {
            require(selectedOptions.length == rules.selectNumbers, "Lotto requires different amount of numbers options");
            for (uint256 i = 0; i < selectedOptions.length; i++) {
                require(selectedOptions[i] >= 1 && selectedOptions[i] <= rules.maxLottoNumbers, "Lotto number out of range");
            }
        } else {
            revert("Invalid game type");
        }
        _;
    }

    function sort(uint[] memory arr) internal pure returns (uint[] memory) {
        uint length = arr.length;
        for (uint i = 0; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (arr[i] > arr[j]) {
                    uint temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
        return arr;
    }

    function areArraysEqual(uint[] memory arr1, uint[] memory arr2) internal pure returns (bool) {
        if (arr1.length != arr2.length) {
            return false;
        }
        uint[] memory sortedArr1 = sort(arr1);
        uint[] memory sortedArr2 = sort(arr2);

        for (uint i = 0; i < sortedArr1.length; i++) {
            if (sortedArr1[i] != sortedArr2[i]) {
                return false;
            }
        }
        return true;
    }

    // END -- HELPER FUNCTIONS

    // START --- SETTERS AND GETTERS

    function getJackPot() public view returns (uint256) {
        return address(this).balance / 2;
    }
    function setGameInfo(GameType _gameType, uint256 _price, uint256 duration) public onlyOwner {
        gameInfos[_gameType].betAmount = _price;
        gameInfos[_gameType].duration = duration;
        gameInfos[_gameType].endDate = 0;
    }
    function getGameEndDate(GameType _gameType) public view returns (uint256) {
        return gameInfos[_gameType].endDate;
    }

    function getGamePrice(GameType _gameType) public view returns (uint256) {
        return gameInfos[_gameType].betAmount;
    }
    function getGameDuration(GameType _gameType) public view returns (uint256) {
        return gameInfos[_gameType].duration;
    }

    function addGameStatus(address _player, TicketStatus memory _gameStatus) internal {
        if (playerStatuses[_player].length == 0) {
            // grab unique users
            users.push(_player);
        }
        playerStatuses[_player].push(_gameStatus);
    }

    function getPlayerGameStatuses(address _player) public view returns (TicketStatus[] memory) {
        return playerStatuses[_player];
    }

    function setLottoRules(uint _maxLottoNumbers, uint _selectNumbers, uint _startMoney) public onlyOwner {
        rules.maxLottoNumbers = _maxLottoNumbers;
        rules.selectNumbers = _selectNumbers;
        rules.startMoneyThreshold = _startMoney;
    }
    // END --- SETTERS AND GETTERS

    // START -- Generation Functions
    function generateRandomNumber(uint256 seed) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, seed)));
    }

    function flipCoin() public view onlyOwner returns (uint256[] memory) {
        uint256 r = generateRandomNumber(block.timestamp);
        uint256 result = r % 2;
        uint256[] memory coinResult = new uint256[](1);
        coinResult[0] = result;
        return coinResult;
    }

    function rollDice() public view onlyOwner returns (uint256[] memory) {
        uint256 r1 = generateRandomNumber(block.timestamp);
        uint256 r2 = generateRandomNumber(block.timestamp + 1);

        uint256 result1 = (r1 % 6) + 1;
        uint256 result2 = (r2 % 6) + 1;

        uint256[] memory diceResult = new uint256[](2);
        diceResult[0] = result1;
        diceResult[1] = result2;
        return diceResult;
    }

    function lottoShuffle() public view onlyOwner returns (uint256[] memory) {
        uint256[] memory allNumbers = new uint256[](rules.maxLottoNumbers);
        uint256[] memory lottoNumbers = new uint256[](rules.selectNumbers);

        for (uint256 i = 0; i < rules.maxLottoNumbers; i++) {
            allNumbers[i] = i + 1;
        }

        for (uint256 i = 0; i < rules.selectNumbers; i++) {
            uint256 randIndex = (generateRandomNumber(block.timestamp + i) % (rules.maxLottoNumbers - i)) + i;
            (allNumbers[i], allNumbers[randIndex]) = (allNumbers[randIndex], allNumbers[i]);
            lottoNumbers[i] = allNumbers[i];
        }

        return lottoNumbers;
    }
    // END -- Generation Functions
}
