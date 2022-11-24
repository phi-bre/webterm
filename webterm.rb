#!/usr/bin/env ruby -w

require 'curses'
require 'ferrum'
require 'oily_png'

BRAILLE = true
PAGE_URL = ARGV.last || 'https://i.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.webp'

puts "Hello World!"

def quantize_pixel(pixel)
  matching_color_index, matching_distance = 0, Float::MAX
  Curses::COLOR_TABLE.each_with_index do |color, index|
    distance = ChunkyPNG::Color.euclidean_distance_rgba(pixel, color)
    if distance < matching_distance
      matching_distance = distance
      matching_color_index = index
    end
  end

  matching_color_index
  # colors[matching_color_index] = ChunkyPNG::Color.blend(pixel, Curses::COLOR_TABLE[matching_color_index])
end

def display(window, browser, offset)
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
      
      color = quantize_pixel(pixels.first)
      window.attron(Curses.color_pair(color) | Curses::A_NORMAL) do
        window.addstr([char].pack('U*'))
      end
    end
  else
    encoding = ' .:-=+*#%@'
    image.pixels.each do |pixel|
      grayscale = ChunkyPNG::Color.grayscale_teint(pixel)
      index = (grayscale / 256.0 * encoding.length).floor
      color = quantize_pixel(pixel)
      window.attron(Curses.color_pair(color) | Curses::A_NORMAL) do
        window.addstr(encoding[index])
      end
    end
  end
end

begin
  Curses.init_screen
  Curses.crmode
  Curses.start_color
  # TODO: Fix the 256 color mode
  (0...Curses.colors).each do |color|
    Curses.init_pair(color, color, Curses::COLOR_BLACK)
  end
  Curses::COLOR_TABLE = (16...Curses.colors).map do |color|
    ChunkyPNG::Color.rgb(*Curses.color_content(color).map { |n| (n / 1000.0 * 255).floor })
  end

  window = Curses::Window.new(0, 0, 0, 0)
  window.keypad(true)
  offset = [0, 0]
  dimensions = [window.maxx, window.maxy]
  dimensions = [window.maxx * 2, window.maxy * 4] if BRAILLE
  browser = Ferrum::Browser.new(window_size: dimensions)
  browser.go_to(PAGE_URL)

  loop do
    window.clear
    display(window, browser, offset)
    window.refresh
    
    case window.getch
      when Curses::KEY_UP then offset[1] -= dimensions[1] / 8
      when Curses::KEY_DOWN then offset[1] += dimensions[1] / 8
      when Curses::KEY_LEFT then offset[0] -= dimensions[0] / 8
      when Curses::KEY_RIGHT then offset[0] += dimensions[0] / 8
      when 'q' then break
    end
  end
ensure
  browser&.quit
  window&.close
  Curses.refresh
  Curses.close_screen
end
