library two_forty_eight;

import "dart:html";
import "dart:async";
import "dart:math";

import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:di/di.dart';


class Cell {
  final int x, y;
  int val;

  Cell(this.x, this.y, [this.val]);
  Cell.copy(Cell cell) : this(cell.x, cell.y, cell.val);

  bool get empty => val == null;
}

class Board {
  static final List<String> DIRECTIONS = const ["up", "down", "left", "right"];

  static final Random _random = new Random();

  List<List<Cell>> rows;

  int score = 0;

  Board([int size = 4]) {
    rows = new List.generate(size, (y) => new List.generate(size, (x) => new Cell(x, y)));
  }

  Board.copy(Board board) {
    rows = board.rows.map((List<Cell> row) => row.map((Cell cell) => new Cell.copy(cell)).toList()).toList();
    score = board.score;
  }

  void copyStateFrom(Board board) {
    if (this == board) {
      return;
    }
    if (size != board.size) {
      throw "different sizes";
    }

    for (int y = 0; y < size; ++y) {
      for (int x = 0; x < size; ++x) {
        rows[y][x].val = board.rows[y][x].val;
      }
    }
    score = board.score;
  }

  int get size => rows.length;

  List<List<Cell>> get columns {
    List<List<Cell>> result = [];
    int size = this.size;
    for (int x = 0; x < size; ++x) {
      List<Cell> col = [];
      for (int y = 0; y < size; ++y) {
        col.add(rows[y][x]);
      }
      result.add(col);
    }
    return result;
  }

  void clear() {
    rows.forEach((List<Cell> row) {
      row.forEach((Cell cell) {
        cell.val = null;
      });
    });
  }

  List<Cell> get openCells {
    List<Cell> result = [];

    rows.forEach((List<Cell> row) {
      row.forEach((Cell cell) {
        if (cell.val == null) {
          result.add(cell);
        }
      });
    });

    return result;
  }

  void addRandom() {
    List<Cell> openCells = this.openCells;

    if (openCells.isNotEmpty) {
      Cell cell = openCells[_random.nextInt(openCells.length)];
      cell.val = _random.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  bool _swap(Cell a, Cell b) {
    if (a != b) {
      int tmp = a.val;
      a.val = b.val;
      b.val = tmp;
      return true;
    } else {
      return false;
    }
  }

  bool _collapse(List<Cell> cells, bool collapseAcrossEmpty) {
    if (!collapseAcrossEmpty) {
      // only keep the cells before the first empty one
      cells = cells.takeWhile((cell) => !cell.empty).toList();
    }

    bool changed = false;
    for (int i = 0; i < cells.length - 1; ++i) {
      Cell cell = cells[i];
      for (int j = i; j < cells.length; ++j) {
        Cell firstNonEmpty = cells[j];
        if (!firstNonEmpty.empty) {
          changed = _swap(cell, firstNonEmpty) || changed;

          // find another one for potential merging
          for (int k = j + 1; k < cells.length; ++k) {
            Cell mergeCell = cells[k];
            if (!mergeCell.empty) {
              if (cell.val == mergeCell.val) {
                cell.val += mergeCell.val;
                mergeCell.val = null;
                score += cell.val;
                changed = true;
              }
              break;
            }
          }
          break;
        }
      }
    }

    return changed;
  }

  bool _collapseCells(Iterable<List<Cell>> cellLists, bool collapseAcrossEmpty) {
    return cellLists.fold(false, (a, cells) => _collapse(cells, collapseAcrossEmpty) || a);
  }

  bool left([bool collapseAcrossEmpty = true]) {
    return _collapseCells(rows, collapseAcrossEmpty);
  }

  bool right([bool collapseAcrossEmpty = true]) {
    return _collapseCells(rows.map((row) => row.reversed.toList()), collapseAcrossEmpty);
  }

  bool up([bool collapseAcrossEmpty = true]) {
    return _collapseCells(columns, collapseAcrossEmpty);
  }

  bool down([bool collapseAcrossEmpty = true]) {
    return _collapseCells(columns.map((column) => column.reversed.toList()), collapseAcrossEmpty);
  }

  bool doDirection(String direction, [bool collapseAcrossEmpty = true]) {
    switch (direction) {
      case "up":
        return up(collapseAcrossEmpty);
      case "down":
        return down(collapseAcrossEmpty);
      case "left":
        return left(collapseAcrossEmpty);
      case "right":
        return right(collapseAcrossEmpty);
      default:
        throw "unknown direction: $direction";
    }
  }

}


class Strategy {
  final String name;
  const Strategy(this.name);
  String nextDirection(Board board) => null;
}

class RandomStrategy extends Strategy {
  static final Random _random = new Random();

  const RandomStrategy() : super("random");

  String nextDirection(Board board) {
    return Board.DIRECTIONS[_random.nextInt(Board.DIRECTIONS.length)];
  }
}

class UpLeftRightDownStrategy extends Strategy {
  const UpLeftRightDownStrategy() : super("up left right down");

  String nextDirection(Board board) {
    Board tmp = new Board.copy(board);
    return ["up", "left", "right", "down"].firstWhere((dir) => tmp.doDirection(dir), orElse: () => null);
  }
}

class EvaluateStrategy extends Strategy {
  final int searchDepth;
  final bool sumScores;

  const EvaluateStrategy(String name, this.searchDepth, [this.sumScores = false]) : super(name);

  num evaluate(List<Board> boards, List<String> moves) {
    return boards.last.score;
  }

  num _search(List<Board> boards, List<String> previousMoves) {
    if (previousMoves.length >= searchDepth) {
      return evaluate(boards, previousMoves);
    }

    num baseScore = 0;
    if (sumScores) {
      baseScore = evaluate(boards, previousMoves);
    }

    num bestScore = null;
    Board.DIRECTIONS.forEach((String dir) {
      Board tmp = new Board.copy(boards.last);
      if (tmp.doDirection(dir, false)) {
        num score = baseScore + _search(new List.from(boards)..add(tmp), new List.from(previousMoves)..add(dir));
        if (bestScore == null || score > bestScore) {
          bestScore = score;
        }
      }
    });

    return bestScore != null ? bestScore : evaluate(boards, previousMoves);
  }

  String nextDirection(Board board) {
    String best = null;
    num bestScore = null;
    Board.DIRECTIONS.forEach((String dir) {
      Board tmp = new Board.copy(board);
      if (tmp.doDirection(dir)) {
        num score = _search([board, tmp], [dir]);
        if (bestScore == null || score > bestScore) {
          best = dir;
          bestScore = score;
        }
      }
    });

    return best;
  }
}

class GreedyStrategy extends EvaluateStrategy {
  const GreedyStrategy(int searchDepth) : super("greedy $searchDepth", searchDepth);

  num evaluate(List<Board> boards, List<String> moves) {
    return boards.last.score * boards[1].openCells.length;
  }
}

class AntiGreedyStrategy extends EvaluateStrategy {
  const AntiGreedyStrategy(int searchDepth) : super("anti greedy $searchDepth", searchDepth);

  num evaluate(List<Board> boards, List<String> moves) {
    return -boards.last.score;
  }
}

class GreedyDownStrategy extends EvaluateStrategy {
  const GreedyDownStrategy(int searchDepth) : super("greedy $searchDepth down", searchDepth);

  num evaluate(List<Board> boards, List<String> moves) {
    if (moves.any((dir) => dir == "up")) {
      return -1;
    } else {
      Board boardAfterFirst = boards[1];
      // try to keep as many rows as possible non-empty to avoid up
      int nonEmptyRows = boardAfterFirst.rows.where((row) => row.any((cell) => !cell.empty)).length;
      return boards.last.score * nonEmptyRows * boardAfterFirst.openCells.length;
    }
  }
}

class EdgeStrategy extends EvaluateStrategy {
  const EdgeStrategy(int searchDepth) : super("edge $searchDepth", searchDepth, true);

  num _cellScore(Cell cell) {
    if (cell.empty) {
      return 0;
    }
    num x = log(cell.val) / log(2);
    return x * x;
  }

  num _edgeCellScore(Cell cell, Board board) {
    num s = _cellScore(cell);

    if (cell.y == 0) {
      s *= s;
      if (cell.x == 0) {
        s *= s;
      }
    }
    return s / (cell.y + 1);
  }

  num evaluate(List<Board> boards, List<String> moves) {
    num score = 0;
    boards.last.rows.forEach((row) {
      row.forEach((cell) {
        score += _edgeCellScore(cell, boards.last);
      });
    });
    return score;
  }
}


@Component(selector: "two-forty-eight", template: """
<h1>Two forty eight</h1>

<div>
  <button ng-click="newGame()">New game</button>
  <button ng-click="clear()">Clear</button>
  <button ng-click="addRandom()">Add random</button>
</div>

<div>
  <button ng-click="undo()">Undo</button>
  -
  <button ng-click="left()">left</button>
  <button ng-click="right()">right</button>
  <button ng-click="up()">up</button>
  <button ng-click="down()">down</button>
</div>

<div>
  <label>Strategy:
    <select ng-model="strategy">
      <option ng-repeat="s in strategies" ng-value="s">{{s.name}}</option>
    </select>
  </label>
  <br>
  <label>Run: <input type="checkbox" ng-model="run"></label>
  <br>
  <label>Delay: <input type="range" min="5" max="1000" ng-model="runDelay"></label>
  <br>
  Score: {{board.score}} <strong>{{gameOver ? 'Game Over' : ''}}</strong>
</div>

<table>
  <tr ng-repeat="row in board.rows">
    <td ng-repeat="cell in row">
      {{cell.val}}
    </td>
  <tr>
</table>
""", exportExpressions: const ['[run, runDelay]'], useShadowDom: false)
class AppController extends ScopeAware {
  Board board = new Board();

  List<Board> undos = [];

  bool gameOver = false;

  bool run = false;
  num runDelay = 50;
  Timer currentTimer;

  List<Strategy> strategies;

  Strategy strategy;

  AppController(Element element) {
    strategies =
        [const RandomStrategy(), const UpLeftRightDownStrategy(), const AntiGreedyStrategy(1), const AntiGreedyStrategy(2)];
    for (int i = 1; i < 10; ++i) {
      strategies.add(new GreedyStrategy(i));
    }
    for (int i = 1; i < 10; ++i) {
      strategies.add(new GreedyDownStrategy(i));
    }
    for (int i = 1; i < 10; ++i) {
      strategies.add(new EdgeStrategy(i));
    }

    strategy = strategies.first;

    element.onKeyDown.listen(keyDown);
  }

  @override
  void set scope(Scope scope) {
    scope.watch('[run, runDelay]', (v, _) {
      if (currentTimer != null) {
        currentTimer.cancel();
        currentTimer = null;
      }
      setupTimer();
    }, context: this);
  }

  setupTimer() {
    if (run) {
      currentTimer = new Timer(new Duration(milliseconds: runDelay.toInt()), () {
        currentTimer = null;
        if (run) {
          step();
          setupTimer();
        }
      });
    }
  }

  void step() {
    if (strategy != null) {
      String next = strategy.nextDirection(new Board.copy(board));

      if (next != null) {
        doDirection(next);
      }
    }
  }

  void clear() {
    board.clear();
    gameOver = false;
  }

  void _checkGameOver() {
    if (board.openCells.isEmpty) {
      Board tmp = new Board.copy(board);
      if (!(tmp.left() || tmp.right() || tmp.up() || tmp.down())) {
        gameOver = true;
      }
    }
  }

  void addRandom() {
    board.addRandom();
    _checkGameOver();
  }

  void newGame() {
    clear();
    addRandom();
    addRandom();
    board.score = 0;
  }

  void saveUndo() {
    undos.add(new Board.copy(board));
    while (undos.length > 1000) {
      undos.removeAt(0);
    }
  }

  void undo() {
    if (undos.isNotEmpty) {
      board.copyStateFrom(undos.removeLast());
    }
  }

  void _handleNoChange() {
    undos.removeLast();
    _checkGameOver();
  }

  void doDirection(String direction) {
    saveUndo();
    if (board.doDirection(direction)) {
      addRandom();
    } else {
      _handleNoChange();
    }
  }

  void doDirectionOnlyNonEmpty(String direction) {
    saveUndo();
    board.doDirection(direction, false);
  }

  void left() {
    doDirection("left");
  }

  void right() {
    doDirection("right");
  }

  void up() {
    doDirection("up");
  }

  void down() {
    doDirection("down");
  }

  void keyDown(KeyboardEvent event) {
    switch (event.keyCode) {
      // arrow keys
      case 37:
        left();
        break;
      case 38:
        up();
        break;
      case 39:
        right();
        break;
      case 40:
        down();
        break;

      // wasd
      case 65:
        doDirectionOnlyNonEmpty("left");
        break;
      case 87:
        doDirectionOnlyNonEmpty("up");
        break;
      case 68:
        doDirectionOnlyNonEmpty("right");
        break;
      case 83:
        doDirectionOnlyNonEmpty("down");
        break;
    }
  }

}


void main() {
  applicationFactory().addModule(new Module()..bind(AppController)).run();
}
