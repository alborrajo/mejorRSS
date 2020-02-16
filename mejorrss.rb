#!/usr/bin/ruby -w
require 'nokogiri'
require 'open-uri'

require 'rss'

require './scrappedElement.rb'

if ARGV.empty?
    puts "Usage: #{$0} <URI>"
    exit
end
target = URI(ARGV[0])

doc = Nokogiri::HTML(URI.open(target))

rss = RSS::Maker.make("2.0") do |maker|
    maker.channel.updated       = Time.now.to_s
    maker.channel.about         = target.to_s
    maker.channel.link          = target.to_s
    maker.channel.description   = "MejorTorrent"
    maker.channel.title         = "MejorTorrent"
    maker.channel.author        = "MejorTorrent"

    category = nil
    date = nil
    title = nil
    link = nil

    scrappedElements = []
    doc.css("div#main_table_center_center1 > table > tr > td > div > *").each do |element|
        # Current section: DOCUMENTALES, PELICULAS, SERIES
        if element.name == "div"
            category = element.content
        end

        # Torrent itself:
        #   <span> with date
        #   <a> with title and link to torrent
        #   [<span> with quality]
        
        if element.name == "span" and date == nil
            date = element.content
        end

        if element.name == "a"
            title = element.content
            link = URI.join(target, element["href"])
        end

        # 01-02-2003 Name of the Movie --> (Quality) <--
        if category == "PELÍCULAS:" and element.name == "span" and element.next_element.name == "br"
            title = title + " #{element.content}"
        end

        if element.name == "br"
            scrappedElement = ScrappedElement.new
            scrappedElement.category = category
            scrappedElement.updated = date
            scrappedElement.title = title
            scrappedElement.link = link
            scrappedElements << scrappedElement

            date = nil
            title = nil
            link = nil
        end
    end

    threads = []
    scrappedElements.each do |scrappedElement|
        #puts scrappedElement.link
        threads << Thread.new do 
            scrappedElement.buildRSS(maker)
        end
    end

    threads.each do |thread|
        thread.join
    end

end

puts rss
