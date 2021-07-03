require 'set'
require_relative 'character'

include MiniGL

TILE_SIZE = 128
HALF_TILE = 64

class Tile
  CHAR_OFFSETS = [
    [[0, 0, 0]],
    [[-32, -32, 0], [32, 32, 1]],
    [[-32, -32, 0], [32, -32, 1], [0, 32, 2]]
  ]

  attr_reader :col, :row, :directions
  
  def initialize(i, j, dir_mask)
    @col = i
    @row = j
    @center = Vector.new(i * TILE_SIZE + TILE_SIZE / 2, j * TILE_SIZE + TILE_SIZE / 2)
    @directions = Set.new
    @directions.add(:up) if (dir_mask & 1) > 0
    @directions.add(:rt) if (dir_mask & 2) > 0
    @directions.add(:dn) if (dir_mask & 4) > 0
    @directions.add(:lf) if (dir_mask & 8) > 0
    @characters = []
  end

  def set_floor_type(board_id, up, rt, dn, lf)
    floor_type =
      if up && dn || rt && lf then 0
      elsif dn && !rt && !lf then 1
      elsif lf && !up && !dn then 2
      elsif up && !rt && !lf then 3
      elsif rt && !up && !dn then 4
      elsif dn && lf then 5
      elsif up && lf then 6
      elsif up && rt then 7
      else 8
      end
    @img = Res.imgs("board_floor#{board_id}", 3, 3)[floor_type]
  end
  
  def add_char(char, start = false)
    @characters << char
    char.tile = self
    reposition_chars(start)
  end

  def remove_char(char)
    @characters.delete(char)
    reposition_chars
  end

  def draw(map)
    x = @col * TILE_SIZE - map.cam.x
    y = @row * TILE_SIZE - map.cam.y
    @img.draw(x + 8, y + 8, 1, 1, 1, 0x33000000)
    @img.draw(x, y, 2)
    G.window.draw_triangle(x + HALF_TILE, y - 4, 0xffffff00,
                           x + HALF_TILE - 8, y + 4, 0xffffff00,
                           x + HALF_TILE + 8, y + 4, 0xffffff00, 3) if @directions.include?(:up)
    G.window.draw_triangle(x + TILE_SIZE + 4, y + HALF_TILE, 0xffffff00,
                           x + TILE_SIZE - 4, y + HALF_TILE - 8, 0xffffff00,
                           x + TILE_SIZE - 4, y + HALF_TILE + 8, 0xffffff00, 3) if @directions.include?(:rt)
    G.window.draw_triangle(x + HALF_TILE, y + TILE_SIZE + 4, 0xffffff00,
                           x + HALF_TILE - 8, y + TILE_SIZE - 4, 0xffffff00,
                           x + HALF_TILE + 8, y + TILE_SIZE - 4, 0xffffff00, 3) if @directions.include?(:dn)
    G.window.draw_triangle(x - 4, y + HALF_TILE, 0xffffff00,
                           x + 4, y + HALF_TILE - 8, 0xffffff00,
                           x + 4, y + HALF_TILE + 8, 0xffffff00, 3) if @directions.include?(:lf)
  end

  private

  def reposition_chars(start = false)
    offsets = CHAR_OFFSETS[@characters.size - 1]
    @characters.each_with_index do |c, i|
      c.send(start ? :set_position : :set_target, @center.x + offsets[i][0], @center.y + offsets[i][1])
      c.z_offset = offsets[i][2]
    end
  end
end

class Board
  def initialize(id)
    @bg = Res.img("board_bg#{id}")
    @die = Sprite.new(40, 40, :ui_die, 2, 3)

    File.open("#{Res.prefix}board/#{id}") do |f|
      f.each_line.with_index do |line, j|
        line = line.chomp
        case j
        when 0
          @width, @height = line.split(',').map(&:to_i)
          @tiles = Array.new(@width) do
            Array.new(@height)
          end
        when 1
          @start_point = line.split(',').map(&:to_i)
        else
          (0...line.size).each do |i|
            @tiles[i][j - 2] = Tile.new(i, j - 2, line[i].to_i(16)) if line[i] != '.'
          end
        end
      end
    end

    @map = Map.new(TILE_SIZE, TILE_SIZE, @width, @height, G.window.width, G.window.height, false, false)
    map_size = @map.get_absolute_size
    @map.set_camera((map_size.x - G.window.width) / 2, (map_size.y - G.window.height) / 2)

    @tiles.each_with_index do |col, i|
      col.each_with_index do |tile, j|
        next unless tile

        up = j > 0 && @tiles[i][j - 1]
        rt = i < @tiles.size - 1 && @tiles[i + 1][j]
        dn = j < @tiles[0].size - 1 && @tiles[i][j + 1]
        lf = i > 0 && @tiles[i - 1][j]
        @tiles[i][j].set_floor_type(id, up, rt, dn, lf)
      end
    end

    @characters = []
    @char_index = 0
    @state = :rolling
  end

  def add_character(name)
    @characters << (char = Character.new(name))
    @tiles[@start_point[0]][@start_point[1]].add_char(char, true)
  end

  def update
    @characters.each(&:update)

    case @state
    when :rolling
      @die.animate([0, 1, 2, 3, 4, 5], 5)
      if KB.key_pressed?(Gosu::KB_SPACE)
        @moves = @die.img_index + 1
        @state = :moving
      end
    when :moving
      cur_char = @characters[@char_index]
      return if cur_char.moving?

      if @moves == 0
        change_turn
        return
      end

      tile = cur_char.tile
      if tile.directions.empty?
        change_turn
      elsif tile.directions.size == 1
        if tile.directions.include?(:up)
          move_char(cur_char, @tiles[tile.col][tile.row - 1])
        elsif tile.directions.include?(:rt)
          move_char(cur_char, @tiles[tile.col + 1][tile.row])
        elsif tile.directions.include?(:dn)
          move_char(cur_char, @tiles[tile.col][tile.row + 1])
        else # :lf
          move_char(cur_char, @tiles[tile.col - 1][tile.row])
        end
      elsif tile.directions.include?(:up) && KB.key_pressed?(Gosu::KB_UP)
        move_char(cur_char, @tiles[tile.col][tile.row - 1])
      elsif tile.directions.include?(:rt) && KB.key_pressed?(Gosu::KB_RIGHT)
        move_char(cur_char, @tiles[tile.col + 1][tile.row])
      elsif tile.directions.include?(:dn) && KB.key_pressed?(Gosu::KB_DOWN)
        move_char(cur_char, @tiles[tile.col][tile.row + 1])
      elsif tile.directions.include?(:lf) && KB.key_pressed?(Gosu::KB_LEFT)
        move_char(cur_char, @tiles[tile.col - 1][tile.row])
      end
    end
  end

  def change_turn
    @char_index += 1
    @char_index = 0 if @char_index >= @characters.size
    @state = :rolling
    @die.set_animation(0)
  end

  def move_char(char, to)
    char.tile.remove_char(char)
    to.add_char(char)
    @moves -= 1
  end

  def draw
    x = 0
    while x < G.window.width
      y = 0
      while y < G.window.height
        @bg.draw(x, y, 0)
        y += @bg.height
      end
      x += @bg.width
    end

    @tiles.each_with_index do |col, i|
      col.each_with_index do |tile, j|
        tile&.draw(@map)
      end
    end

    @characters.each do |c|
      c.draw(@map)
    end

    @die.draw(nil, 1, 1, 255, 0xffffff, nil, nil, 100)
  end
end
