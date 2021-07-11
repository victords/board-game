require 'set'
require_relative 'character'

include MiniGL

TILE_SIZE = 128
HALF_TILE = 64

class Tile
  ELEMENT_OFFSETS = [
    [[0, 0]],
    [[-21, -21], [21, 21, 1]],
    [[-27, -23], [27, -23], [0, 23, 1]],
    [[-30, -30], [30, -30], [-30, 30, 1], [30, 30, 1]],
    [[-30, -30], [30, -30], [0, 0, 1], [-30, 30, 2], [30, 30, 2]],
  ].freeze
  MAX_GEMS = 5

  attr_reader :col, :row, :directions
  
  def initialize(board, col, row, content)
    @board = board
    @col = col
    @row = row
    @center = Vector.new(col * TILE_SIZE + TILE_SIZE / 2, row * TILE_SIZE + TILE_SIZE / 2)

    dir_mask = content[0].to_i(16)
    @directions = Set.new
    @directions.add(:up) if (dir_mask & 1) > 0
    @directions.add(:rt) if (dir_mask & 2) > 0
    @directions.add(:dn) if (dir_mask & 4) > 0
    @directions.add(:lf) if (dir_mask & 8) > 0

    @props = {
      gems: []
    }

    gem_count = content[1].to_i
    gem_img = Res.imgs(:board_smallGem, 3, 1)[0]
    big_gem_img = Res.imgs(:board_bigGem, 3, 1)[0]

    if gem_count > MAX_GEMS
      x = @center.x - big_gem_img.width / 2
      y = @center.y - big_gem_img.height / 2
      @props[:big_gem] = Sprite.new(x, y, :board_bigGem, 3, 1)
      @board.big_gem_count += 1
    else
      offsets = ELEMENT_OFFSETS[gem_count - 1]
      (0...gem_count).each do |i|
        x = @center.x + offsets[i][0] - gem_img.width / 2
        y = @center.y + offsets[i][1] - gem_img.height / 2
        @props[:gems] << Sprite.new(x, y, :board_smallGem, 3, 1)
      end
    end

    @characters = []
  end

  def set_floor_type(up, rt, dn, lf)
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
    @img = Res.imgs("board_floor#{@board.id}", 3, 3)[floor_type]
    @gem_tint = case @board.id
                when 1 then 0xff5050
                else        0xffffff
                end
  end
  
  def add_char(char, end_turn, start = false)
    @characters << char
    char.tile = self
    reposition_chars(start)
    return unless end_turn

    char.score += @props[:big_gem] ? 100 : @props[:gems].size
    if @props[:big_gem]
      @board.big_gem_count -= 1
      @props[:big_gem] = nil
    end
  end

  def remove_char(char)
    @characters.delete(char)
    reposition_chars
  end

  def update
    @props[:gems].each do |gem|
      gem.animate([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1], 7)
    end
    @props[:big_gem]&.animate([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1], 7)
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

    @props[:gems].each_with_index do |gem, i|
      gem.draw(map, 1, 1, 255, @gem_tint, nil, nil, 4 + (ELEMENT_OFFSETS[@props[:gems].size - 1][i][2] || 0))
    end
    @props[:big_gem]&.draw(map, 1, 1, 255, @gem_tint, nil, nil, 4)
  end

  private

  def reposition_chars(start = false)
    offsets = ELEMENT_OFFSETS[@characters.size - 1]
    @characters.each_with_index do |c, i|
      c.send(start ? :set_position : :set_target, @center.x + offsets[i][0], @center.y + offsets[i][1])
      c.z_offset = (offsets[i][2] || 0) + @row
    end
  end
end

class Board
  attr_reader :id
  attr_accessor :big_gem_count

  def initialize(id)
    @id = id
    @bg = Res.img("board_bg#{id}")
    @die = Sprite.new(40, 40, :ui_die, 2, 3)
    @font = Res.font(:arialRounded, 36)
    @big_gem_count = 0

    File.open("#{Res.prefix}board/#{id}") do |f|
      data = f.read.split('|')
      @width, @height = data[0].split(',').map(&:to_i)
      @start_col, @start_row = data[1].split(',').map(&:to_i)
      @tiles = Array.new(@width) do
        Array.new(@height)
      end
      data[2].split(';').each do |t|
        d = t.split(':')
        col, row = d[0].split(',').map(&:to_i)
        @tiles[col][row] = Tile.new(self, col, row, d[1].split(','))
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
        @tiles[i][j].set_floor_type(up, rt, dn, lf)
      end
    end

    @characters = []
    @char_index = 0
    @state = :rolling
  end

  def add_character(name)
    @characters << (char = Character.new(name))
    @tiles[@start_col][@start_row].add_char(char, false, true)
  end

  def update
    @characters.each(&:update)
    @tiles.each do |col|
      col.each do |tile|
        tile&.update
      end
    end

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
    if @big_gem_count.zero?
      @state = :finished
      return
    end
    @char_index += 1
    @char_index = 0 if @char_index >= @characters.size
    @state = :rolling
    @die.set_animation(0)
  end

  def move_char(char, to)
    char.tile.remove_char(char)
    to.add_char(char, @moves == 1)
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

    @tiles.each do |col|
      col.each do |tile|
        tile&.draw(@map)
      end
    end

    @characters.each_with_index do |c, i|
      c.draw(@map)
      @font.draw_text(c.score.to_s, 40 + i * 80, G.window.height - 76, 100, 1, 1, 0xff000000)
    end

    if @state == :finished
      @font.draw_text_rel('FINISHED', G.window.width / 2, G.window.height / 2, 100, 0.5, 0.5, 2, 2, 0xff000000)
    else
      @die.draw(nil, 1, 1, 255, 0xffffff, nil, nil, 100)
      @font.draw_text('Score', 40, G.window.height - 116, 100, 1, 1, 0xff000000)
    end
  end
end
