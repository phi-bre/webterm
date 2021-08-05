#!/usr/bin/env ruby -w

require 'curses'
require 'ferrum'
require 'chunky_png'

def display(win, browser, width, height, top, left)
  encoding = ' .:-=+*#%@'
  browser.mouse.scroll_to(top, left)
  browser.screenshot(path: 'tmp.png')

  image = ChunkyPNG::Image.from_file('tmp.png')
  (0...height).each do |y|
    (0...width).each do |x|
      pixel = image[x, y]
      r = ChunkyPNG::Color.r(pixel)
      g = ChunkyPNG::Color.g(pixel)
      b = ChunkyPNG::Color.b(pixel)
      grayscale = (r + g + b) / 3.0
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
  top = 0
  left = 0
  browser = Ferrum::Browser.new(window_size: [width, height])
  browser.go_to(ARGV.last || 'https://i.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.webp')
  # browser.go_to('http://motherfuckingwebsite.com/')

  loop do
    win.clear
    display(win, browser, width, height, left, top)
    win.refresh
    case win.getch
    when KEY_UP then top -= 1
    when KEY_DOWN then top += 1
    when KEY_LEFT then left - 1
    when KEY_RIGHT then left + 1
    end
  end
ensure
  browser&.quit
  win&.close
  Curses.refresh
  Curses.close_screen
end
