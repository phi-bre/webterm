#!/usr/bin/env ruby -w

require 'curses'
require 'ferrum'
require 'chunky_png'

BRAILLE = false
PAGE_URL = ARGV.last || 'https://i.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.webp'

def display(win, browser, offset)
  browser.mouse.scroll_to(*offset)
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
  offset = [0, 0]
  dimensions = [win.maxx, win.maxy]
  dimensions = [win.maxx * 2, win.maxy * 4] if BRAILLE
  browser = Ferrum::Browser.new(window_size: dimensions)
  browser.go_to(PAGE_URL)

  loop do
    win.clear
    display(win, browser, offset)
    win.refresh
    
    case win.getch
      when Curses::KEY_UP then offset[0] -= dimensions[1] / 8
      when Curses::KEY_DOWN then offset[0] += dimensions[1] / 8
      when Curses::KEY_LEFT then offset[1] -= dimensions[0] / 8
      when Curses::KEY_RIGHT then offset[1] += dimensions[0] / 8
    end
  end
ensure
  browser&.quit
  win&.close
  Curses.refresh
  Curses.close_screen
end
