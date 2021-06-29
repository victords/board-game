require 'minigl'
require_relative 'board'

include MiniGL

class MyGameWindow < GameWindow
  def initialize
    w, h = `xrandr`.scan(/current (\d+) x (\d+)/).flatten.map(&:to_i)
    super(w, h)

    Res.prefix = "#{File.expand_path(__FILE__).split('/')[0..-3].join('/')}/data"
    @board = Board.new(1)
    @board.add_character('cat')
    @board.add_character('rabbit')
  end

  def update
    KB.update
    close if KB.key_pressed?(Gosu::KB_ESCAPE)

    @board.update
  end

  def draw
    @board.draw
  end
end

MyGameWindow.new.show
