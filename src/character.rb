include MiniGL

class Character < GameObject
  IMAGE_GAPS = {
    'cat' => Vector.new(0, 0),
    'rabbit' => Vector.new(0, -14)
  }

  def initialize(name, x, y)
    super(x, y, 128, 128, "char_#{name}", IMAGE_GAPS[name], 2, 1)
  end

  def update
    animate([0, 1], 15)
  end

  def draw
    super(nil, 1, 1, 255, 0xffffff, nil, nil, 3)
  end
end
