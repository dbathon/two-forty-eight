library two_forty_eight;

import "dart:html";
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

}


@NgController(selector: "[main-ctrl]", publishAs: "c")
class AppController {
  Board board = new Board();

  bool gameOver = false;

  AppController(Element element) {
    element.onKeyDown.listen(keyDown);
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

  void handleNoChange() {
    _checkGameOver();
  }

  void left() {
    if (board.left()) {
      board.addRandom();
    } else {
      handleNoChange();
    }
  }

  void right() {
    if (board.right()) {
      board.addRandom();
    } else {
      handleNoChange();
    }
  }

  void up() {
    if (board.up()) {
      board.addRandom();
    } else {
      handleNoChange();
    }
  }

  void down() {
    if (board.down()) {
      board.addRandom();
    } else {
      handleNoChange();
    }
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
