#!/usr/bin/env ruby -w

require 'curses'
require 'ferrum'
require 'chunky_png'

BRAILLE = false

def display(win, browser, top, left)
  browser.mouse.scroll_to(top, left)
  browser.screenshot(path: 'tmp.png')
  image = ChunkyPNG::Image.from_file('tmp.png')

  if BRAILLE
    chars = (0...image.width * image.height / 8).map do |index|
      cx = index * 2 % image.width
      cy = index * 7 / image.width # TODO: Should be * 8, but it ends up out of bounds
      pixels = [
        image[cx + 0, cy + 0],
        image[cx + 0, cy + 1],
        image[cx + 0, cy + 2],
        image[cx + 1, cy + 0],
        image[cx + 1, cy + 1],
        image[cx + 1, cy + 2],
        image[cx + 0, cy + 3],
        image[cx + 1, cy + 3],
      ]
      pixels.map { |pixel| (2.0 / 256.0 * ChunkyPNG::Color.grayscale_teint(pixel)).floor }.reverse.join('').to_i(2) + 0x2800
    end
    win.addstr(chars.pack('U*'))
  else
    encoding = ' .:-=+*#%@'
    image.pixels.each do |pixel|
      grayscale = ChunkyPNG::Color.grayscale_teint(pixel)
      index = (grayscale / 256.0 * encoding.length).floor
      win.addstr(encoding[index])
    end
  end
end

begin
  Curses.init_screen
  Curses.crmode

  win = Curses::Window.new(0, 0, 0, 0)
  win.keypad(true)
  width = win.maxx
  height = win.maxy
  if BRAILLE
    width *= 2
    height *= 4
  end
  top = 0
  left = 0
  browser = Ferrum::Browser.new(window_size: [width, height])
  browser.go_to(ARGV.last || 'https://i.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.webp')

  loop do
    win.clear
    display(win, browser, left, top)
    win.refresh
    case win.getch
    when Curses::KEY_UP then top -= height / 8
    when Curses::KEY_DOWN then top += height / 8
    when Curses::KEY_LEFT then left -= width / 8
    when Curses::KEY_RIGHT then left += width / 8
    end
  end
ensure
  browser&.quit
  win&.close
  Curses.refresh
  Curses.close_screen
end
