include MiniGL

class Character < GameObject
  IMAGE_GAPS = {
    rabbit: Vector.new(0, -14),
  }.freeze

  SPEED = 4

  attr_writer :z_offset
  attr_accessor :tile, :score, :extra_rolls, :extra_dice

  def initialize(board, name)
    super(0, 0, 128, 128, "char_#{name}", IMAGE_GAPS[name], 2, 1)
    @board = board
    @name = name
    @score = 0
    @z_offset = 0
    @extra_rolls = 0
    @extra_dice = 0
    @cooldown = 0
  end

  def update
    animate([0, 1], 15)
    if @target
      move_free(@target, 3)
      @target = nil if @speed.x == 0 && @speed.y == 0
    end
  end

  def start_turn
    @cooldown -= 1 if @cooldown.positive?

    case @name
    when :cat
      @extra_rolls = 1
    when :rabbit
      if @cooldown.zero?
        @board.add_option('Ability: + 1 die') do
          @extra_dice = 1
          @cooldown = 3
        end
      end
    when :duck
      @tile.unset_prop(:blocked)
    end

    @current = true
  end

  def set_position(x, y)
    @x = x - @w / 2
    @y = y - @h
  end

  def set_target(x, y)
    @target = Vector.new(x - @w / 2, y - @h)
  end

  def set_cooldown
    case @name
    when :rabbit, :duck
      @cooldown = 3
    end
  end

  def moving?
    @speed.x != 0 || @speed.y != 0
  end

  def after_move
    case @name
    when :duck
      @board.add_option('Block path', true) do
        @tile.set_prop(:blocked)
      end
    end
  end

  def end_turn
    @current = false
  end

  def draw(map)
    alpha = @current ? 255 : 127
    super(map, 1, 1, alpha, 0xffffff, nil, nil, 9 + @z_offset)
  end
end
