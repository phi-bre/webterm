#!/usr/bin/env ruby -w

require 'curses'
require 'ferrum'
require 'chunky_png'

BRAILLE = true
PAGE_URL = ARGV.last || 'https://i.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.webp'

def quantize(image)
  colors = (0...Curses.colors).map { |color| ChunkyPNG::Color.rgb(*Curses.color_content(color)) }
  
  image.pixels.each do |pixel|
    matching_color_index = 0
    matching_distance = Float::MAX
    colors.each_with_index do |color, index|
      distance = ChunkyPNG::Color.euclidean_distance_rgba(pixel, color)
      if distance < matching_distance
        matching_distance = distance
        matching_color_index = index
      end
    end

    colors[matching_color_index] = ChunkyPNG::Color.blend(pixel, colors[matching_color_index])
  end

  colors
end

XTERM_TABLE = [0, 95, 135, 175, 215, 255]
XTERM_COLORS = (0..239).map do |n|
  if n < 216
    [XTERM_TABLE[n / 36], XTERM_TABLE[(n % 36) / 6], XTERM_TABLE[n % 6]] 
  else 
    [n * 10 - 2152] * 3
  end
end

def to_xterm_256(color) # Yoinked from https://codegolf.stackexchange.com/a/156932
  rgb = ChunkyPNG::Color.to_truecolor_bytes(color)
  color_list = XTERM_COLORS.map do |c|
    c.zip(rgb).map { |a, b| (a - b).abs }.sum
  end
  color_list.rindex(color_list.min) + 16
end

# Curses.start_color
# image = ChunkyPNG::Image.from_file('tmp.png')
# puts ChunkyPNG::Color.pixel_bitsize(ChunkyPNG::COLOR_INDEXED)
# puts quantize(image).map { |color| ChunkyPNG::Color.to_hex(color, false) }.join(' ')
# return

def display(win, browser, offset)
  browser.mouse.scroll_to(*offset)
  browser.screenshot(path: 'tmp.png')
  image = ChunkyPNG::Image.from_file('tmp.png')
  # TODO: Remove the need tmp files and read the pixels directly off the browser window

  if BRAILLE
    (0...image.width * image.height / 8).each do |index|
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
      char = pixels.map { |pixel| (2.0 / 256.0 * ChunkyPNG::Color.grayscale_teint(pixel)).floor }.reverse.join('').to_i(2) + 0x2800
      
      color = to_xterm_256(pixels.first)
      win.attron(Curses.color_pair(color) | Curses::A_NORMAL) do
        win.addstr([char].pack('U*'))
      end
    end
  else
    encoding = ' .:-=+*#%@'
    image.pixels.each do |pixel|
      grayscale = ChunkyPNG::Color.grayscale_teint(pixel)
      index = (grayscale / 256.0 * encoding.length).floor
      color = to_xterm_256(pixel)
      win.attron(Curses.color_pair(color) | Curses::A_NORMAL) do
        win.addstr(encoding[index])
      end
    end
  end
end

begin
  Curses.init_screen
  Curses.crmode
  Curses.start_color
  (0...Curses.colors).each do |color|
    Curses.init_pair(color, color, Curses::COLOR_BLACK)
  end
  # Curses.init_pair(Curses::COLOR_RED, Curses::COLOR_RED, Curses::COLOR_BLACK)
  # Curses.init_pair(Curses::COLOR_GREEN, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
  # Curses.init_pair(Curses::COLOR_BLUE, Curses::COLOR_BLUE, Curses::COLOR_BLACK)
  # Curses.init_pair(Curses::COLOR_WHITE, Curses::COLOR_WHITE, Curses::COLOR_BLACK)

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
      when Curses::KEY_UP then offset[1] -= dimensions[1] / 8
      when Curses::KEY_DOWN then offset[1] += dimensions[1] / 8
      when Curses::KEY_LEFT then offset[0] -= dimensions[0] / 8
      when Curses::KEY_RIGHT then offset[0] += dimensions[0] / 8
    end
  end
ensure
  browser&.quit
  win&.close
  Curses.refresh
  Curses.close_screen
end
