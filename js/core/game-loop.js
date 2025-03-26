const GameLoop = (function() {
    let isInitialized = false;
    let isRunning = false;
    let isPaused = false;
    let lastUpdateTime = 0;
    let boardElement = null;
    let cellSize = 0;

    function init() {
        if (isInitialized) return;

        console.log("Game initialization started");

        boardElement = document.getElementById('sudoku-board');
        if (!boardElement) {
            console.error("Board element not found");
            return;
        }

        cellSize = Math.floor(boardElement.clientWidth / 9);
        const gameSettings = { cellSize };

        EventSystem.publish(GameEvents.GAME_INIT, gameSettings);
        updateUI();

        isInitialized = true;
        start();

        console.log("Game initialization completed");
    }

    function start() {
        if (isRunning) return;
        isRunning = true;
        isPaused = false;
        lastUpdateTime = performance.now();
        EventSystem.publish(GameEvents.GAME_START);
        requestAnimationFrame(gameLoop);
    }

    function pause() {
        if (!isRunning || isPaused) return;
        isPaused = true;
        EventSystem.publish(GameEvents.GAME_PAUSE);
    }

    function resume() {
        if (!isRunning || !isPaused) return;
        isPaused = false;
        lastUpdateTime = performance.now();
        EventSystem.publish(GameEvents.GAME_RESUME);
        requestAnimationFrame(gameLoop);
    }

    function stop() {
        isRunning = false;
        isPaused = false;
    }

    function reset() {
        console.log("Game reset started");

        stop();

        if (window.PlayerModule) PlayerModule.reset();
        if (window.SudokuBoard) SudokuBoard.reset();
        if (window.EnemyWaves) EnemyWaves.init();
        if (window.TowerPlacement) TowerPlacement.init();

        isInitialized = false;
        init();
        updateUI();

        EventSystem.publish(GameEvents.STATUS_MESSAGE, "New game started!");
        console.log("Game reset completed");
    }

    function gameLoop(timestamp) {
        if (!isRunning || isPaused) return;

        const deltaTime = (timestamp - lastUpdateTime) / 1000;
        lastUpdateTime = timestamp;

        update(deltaTime);
        render();
        requestAnimationFrame(gameLoop);
    }

    function update(deltaTime) {
        try {
            if (window.EnemyWaves) EnemyWaves.update(deltaTime);
            if (window.TowerAttacks) TowerAttacks.update(deltaTime);
            if (window.SudokuCompletion) SudokuCompletion.checkCompletions();
            if (window.CompletionBonusModule) CompletionBonusModule.checkBoardCompletions();
        } catch (error) {
            console.error("Error in game update:", error);
        }
    }

    function render() {
        if (window.BoardRenderer) BoardRenderer.renderEnemies();
    }

    function updateUI() {
        if (window.PlayerModule) {
            const state = PlayerModule.getState();
            const scoreEl = document.getElementById('score-value');
            const livesEl = document.getElementById('lives-value');
            const currencyEl = document.getElementById('currency-value');
            if (scoreEl) scoreEl.textContent = state.score;
            if (livesEl) livesEl.textContent = state.lives;
            if (currencyEl) currencyEl.textContent = state.currency;
        }

        if (window.EnemyWaves) {
            const waveEl = document.getElementById('wave-value');
            if (waveEl) waveEl.textContent = EnemyWaves.getWaveNumber();
        }

        if (window.SaveSystem && typeof SaveSystem.getHighScore === 'function') {
            const highScore = SaveSystem.getHighScore();
            const hsEl = document.getElementById('high-score-value');
            if (hsEl) hsEl.textContent = highScore;
        }
    }

    function initEventListeners() {
        document.addEventListener('DOMContentLoaded', init);

        EventSystem.subscribe(GameEvents.PLAYER_UPDATE, updateUI);
        EventSystem.subscribe(GameEvents.CURRENCY_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.LIVES_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.SCORE_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.UI_UPDATE, updateUI);

        window.addEventListener('resize', () => {
            if (!boardElement) return;
            cellSize = Math.floor(boardElement.clientWidth / 9);
            if (window.EnemyWaves) EnemyWaves.setCellSize(cellSize);
            if (window.TowerPlacement) TowerPlacement.setCellSize(cellSize);
            if (window.BoardRenderer) BoardRenderer.updateBoard();
        });
    }

    initEventListeners();

    return {
        init,
        start,
        pause,
        resume,
        stop,
        reset,
        updateUI,
        getCellSize: () => cellSize,
        isPaused: () => isPaused,
        isActive: () => isRunning && !isPaused
    };
})();

window.GameLoop = GameLoop;