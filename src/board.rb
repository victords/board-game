require 'set'
require_relative 'character'

include MiniGL

TILE_SIZE = 128
HALF_TILE = 64
DIRECTIONS = %i[up rt dn lf].freeze
DIR_KEYS = {
  up: Gosu::KB_UP,
  rt: Gosu::KB_RIGHT,
  dn: Gosu::KB_DOWN,
  lf: Gosu::KB_LEFT
}.freeze

class Tile
  ELEMENT_OFFSETS = [
    [[0, 0]],
    [[-21, -21], [21, 21, 1]],
    [[-27, -23], [27, -23], [0, 23, 1]],
    [[-30, -30], [30, -30], [-30, 30, 1], [30, 30, 1]],
    [[-30, -30], [30, -30], [0, 0, 1], [-30, 30, 2], [30, 30, 2]],
  ].freeze
  MAX_GEMS = 5

  attr_reader :col, :row, :center, :directions, :characters
  
  def initialize(board, col, row, content)
    @board = board
    @col = col
    @row = row
    @center = Vector.new(col * TILE_SIZE + HALF_TILE, row * TILE_SIZE + HALF_TILE)

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

  def set_prop(prop, value = true)
    @props[prop] = value
  end

  def unset_prop(prop)
    @props.delete(prop)
  end
  
  def is?(flag)
    @props[flag]
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
    @die_img = Res.imgs(:ui_die, 2, 3)
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
    @labels = []
    @buttons = []
    @button_index = 0
    @moves = 0
    @rolled = []

    @state = :choosing_action
    add_default_options
  end

  def add_character(name)
    @characters << (char = Character.new(self, name))
    @tiles[@start_col][@start_row].add_char(char, false, true)
    char.start_turn if @characters.size == 1
  end

  def update
    @characters.each(&:update)
    @tiles.each do |col|
      col.each do |tile|
        tile&.update
      end
    end

    cur_char = @characters[@char_index]
    @map.set_camera(cur_char.x + cur_char.w / 2 - G.window.width / 2,
                    cur_char.y + cur_char.h / 2 - G.window.height / 2)

    case @state
    when :rolling
      @die.animate([0, 1, 2, 3, 4, 5], 5)
      next_roll(cur_char) if KB.key_pressed?(Gosu::KB_SPACE) || KB.key_pressed?(Gosu::KB_RETURN)
    when :moving
      return if cur_char.moving?

      if @moves.zero?
        end_move
        return
      end

      tile = cur_char.tile
      if tile.directions.empty?
        end_move
      else
        DIRECTIONS.each do |dir|
          next unless tile.directions.include?(dir)

          next_tile = case dir
                      when :up then @tiles[tile.col][tile.row - 1]
                      when :rt then @tiles[tile.col + 1][tile.row]
                      when :dn then @tiles[tile.col][tile.row + 1]
                      else          @tiles[tile.col - 1][tile.row]
                      end
          if tile.directions.size == 1
            if next_tile.is?(:blocked)
              end_move
            else
              move_char(cur_char, next_tile)
            end
          elsif KB.key_pressed?(DIR_KEYS[dir]) && !next_tile.is?(:blocked)
            move_char(cur_char, next_tile)
          end
        end
      end
    when :choosing_action, :choosing_target
      if KB.key_pressed?(Gosu::KB_UP) || KB.key_held?(Gosu::KB_UP)
        @button_index -= 1
        @button_index = @buttons.size - 1 if @button_index < 0
      elsif KB.key_pressed?(Gosu::KB_DOWN) || KB.key_held?(Gosu::KB_DOWN)
        @button_index += 1
        @button_index = 0 if @button_index >= @buttons.size
      elsif KB.key_pressed?(Gosu::KB_SPACE) || KB.key_pressed?(Gosu::KB_RETURN)
        @buttons[@button_index].click
      end
    end
  end

  def next_roll(char)
    rolled = @die.img_index + 1
    @moves += rolled
    @rolled << rolled
    @die.x += @die_img[0].width + 20
    if char.extra_rolls > 0
      set_state :choosing_action
      @labels = [
        Label.new(40, 200, @font, 'Try again?')
      ]
      @buttons = [
        Button.new(40, 250, @font, 'Yes', :ui_button1) do
          @moves -= @rolled.pop
          @die.x -= @die_img[0].width + 20
          char.extra_rolls -= 1
          set_state :rolling
        end,
        Button.new(40, 310, @font, 'No', :ui_button1) do
          set_state :moving
        end
      ]
    elsif char.extra_dice > 0
      char.extra_dice -= 1
      set_state :rolling
    else
      set_state :moving
    end
  end

  def move_char(char, to)
    char.tile.remove_char(char)
    to.add_char(char, @moves == 1)
    @moves -= 1
  end

  def end_move
    @moves = 0
    @rolled.clear
    @die.x = 40
    @die.set_animation(0)
    set_state :choosing_action

    if @characters[@char_index].after_move
      add_option('Skip', true)
    else
      next_turn
    end
  end

  def next_turn
    if @big_gem_count.zero?
      set_state :finished
      return
    end

    @characters[@char_index].end_turn
    @char_index += 1
    @char_index = 0 if @char_index >= @characters.size

    if @characters[@char_index].stunned?
      @characters[@char_index].start_turn
      next_turn
    else
      set_state :choosing_action
      add_default_options
      @characters[@char_index].start_turn
    end
  end

  def add_default_options
    add_option('Roll die') do
      set_state :rolling
    end
  end

  def add_option(name, end_turn = false, &action)
    @buttons << Button.new(40, 20 + @buttons.size * 60, @font, name, :ui_button1) do
      action&.call
      next_turn if end_turn
    end
  end
  
  def set_targets(tile, range, label, &action)
    targets = @tiles.map do |col|
      col.select { |t| t && t != tile && ((t.col - tile.col).abs + (t.row - tile.row).abs) <= range }.map(&:characters)
    end.flatten
    return false if targets.empty?

    add_option(label) do
      set_state :choosing_target
      targets.each do |t|
        x = t.feet.x - 25
        y = t.feet.y - 25
        @buttons << Button.new(x: x - @map.cam.x, y: y - @map.cam.y, width: 50, height: 50) do
          action.call(t)
          next_turn
        end
      end
    end
  end

  def set_state(state)
    @state = state
    @labels.clear
    @buttons.clear
    @button_index = 0
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

    @labels.each do |l|
      l.draw(255, 100)
    end
    if @buttons.any?
      @buttons.each do |b|
        b.draw(255, 100)
      end
      b = @buttons[@button_index]
      color = @state == :choosing_action ? 0x80ffff00 : 0x80ff0000
      G.window.draw_quad(b.x - 5, b.y - 5, color,
                         b.x + b.w + 5, b.y - 5, color,
                         b.x - 5, b.y + b.h + 5, color,
                         b.x + b.w + 5, b.y + b.h + 5, color, 101)
    end

    if @state == :finished
      @font.draw_text_rel('FINISHED', G.window.width / 2, G.window.height / 2, 100, 0.5, 0.5, 2, 2, 0xff000000)
    else
      @rolled.each_with_index do |n, i|
        @die_img[n - 1].draw(40 + i * (@die_img[0].width + 20), 40, 100)
      end
      @die.draw(nil, 1, 1, 255, 0xffffff, nil, nil, 100) if @state == :rolling
      @font.draw_text('Score', 40, G.window.height - 116, 100, 1, 1, 0xff000000)
    end
  end
end
