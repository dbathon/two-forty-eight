library two_forty_eight;

import "dart:html";
import "dart:async";
import "dart:math";

import 'package:angular/angular.dart';
import 'package:di/di.dart';

// Temporary, please follow https://github.com/angular/angular.dart/issues/476
@MirrorsUsed(targets: const [], override: '*')
import 'dart:mirrors';


class Cell {
  final int x, y;
  int val;

  Cell(this.x, this.y, [this.val]);
  Cell.copy(Cell cell): this(cell.x, cell.y, cell.val);

  bool get empty => val == null;
}

class Board {
  static final List<String> DIRECTIONS = const ["up", "down", "left", "right"];

  static final Random _random = new Random();

  List<List<Cell>> rows;

  int score = 0;

  Board([int size = 4]) {
    rows = new List.generate(size, (y) => new List.generate(size, (x) =>
        new Cell(x, y)));
  }

  Board.copy(Board board) {
    rows = board.rows.map((List<Cell> row) => row.map((Cell cell) =>
        new Cell.copy(cell)).toList()).toList();
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
  bool _collapse(List<Cell> cells) {
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

  bool _collapseCells(Iterable<List<Cell>> cellLists) {
    return cellLists.fold(false, (a, cells) => _collapse(cells) || a);
  }

  bool left() {
    return _collapseCells(rows);
  }

  bool right() {
    return _collapseCells(rows.map((row) => row.reversed.toList()));
  }

  bool up() {
    return _collapseCells(columns);
  }

  bool down() {
    return _collapseCells(columns.map((column) => column.reversed.toList()));
  }

  bool doDirection(String direction) {
    switch (direction) {
      case "up":
        return up();
      case "down":
        return down();
      case "left":
        return left();
      case "right":
        return right();
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

  const RandomStrategy(): super("random");

  String nextDirection(Board board) {
    return Board.DIRECTIONS[_random.nextInt(Board.DIRECTIONS.length)];
  }
}

class Greedy1Strategy extends Strategy {
  const Greedy1Strategy(): super("greedy1");

  String nextDirection(Board board) {
    // best score after two moves
    String best = null;
    int bestScore = -1;
    Board.DIRECTIONS.forEach((String dir) {
      Board tmp = new Board.copy(board);
      if (tmp.doDirection(dir) && tmp.score > bestScore) {
        best = dir;
        bestScore = tmp.score;
      }
    });

    return best;
  }
}

class Greedy2Strategy extends Strategy {
  const Greedy2Strategy(): super("greedy2");

  String nextDirection(Board board) {
    // best score after two moves
    String best = null;
    int bestScore = -1;
    Board.DIRECTIONS.forEach((String dir) {
      Board tmp = new Board.copy(board);
      if (tmp.doDirection(dir)) {
        Board.DIRECTIONS.forEach((String dir2) {
          Board tmp2 = new Board.copy(tmp);

          if (tmp2.doDirection(dir2) && tmp2.score > bestScore) {
            best = dir;
            bestScore = tmp2.score;
          }
        });
      }
    });

    return best;
  }
}

class AntiGreedyStrategy extends Strategy {
  const AntiGreedyStrategy(): super("anti greedy");

  String nextDirection(Board board) {
    // worst score after two moves
    String worst = null;
    int worstScore = null;
    Board.DIRECTIONS.forEach((String dir) {
      Board tmp = new Board.copy(board);
      if (tmp.doDirection(dir) && (worstScore == null || tmp.score <
          worstScore)) {
        worst = dir;
        worstScore = tmp.score;
      }
    });

    return worst;
  }
}

class Greedy2DownStrategy extends Strategy {
  const Greedy2DownStrategy(): super("greedy2 down");

  String nextDirection(Board board) {
    // best score after two moves
    String best = null;
    int bestScore = -1;
    Board.DIRECTIONS.skip(1).forEach((String dir) {
      Board tmp = new Board.copy(board);
      if (tmp.doDirection(dir)) {
        Board.DIRECTIONS.skip(1).forEach((String dir2) {
          Board tmp2 = new Board.copy(tmp);

          if (tmp2.doDirection(dir2) && tmp2.score > bestScore) {
            best = dir;
            bestScore = tmp2.score;
          }
        });
      }
    });

    if (best != null) {
      return best;
    } else {
      return "up";
    }
  }
}


@NgController(selector: "[main-ctrl]", publishAs: "c")
class AppController {
  Board board = new Board();

  List<Board> undos = [];

  bool gameOver = false;

  bool run = false;
  num runDelay = 50;
  Timer currentTimer;

  final List<Strategy> strategies = const [const RandomStrategy(),
      const Greedy1Strategy(), const Greedy2Strategy(), const AntiGreedyStrategy(),
      const Greedy2DownStrategy()];

  Strategy strategy;

  AppController(Element element, Scope scope) {
    strategy = strategies.first;

    element.onKeyDown.listen(keyDown);

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
      currentTimer = new Timer(new Duration(milliseconds: runDelay.toInt()), ()
          {
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
    }
  }

}


class AppModule extends Module {
  AppModule() {
    type(AppController);
  }
}

void main() {
  ngBootstrap(module: new AppModule());
}
