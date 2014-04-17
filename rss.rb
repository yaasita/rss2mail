#!/usr/bin/env ruby
# coding: utf-8
#############################################
urls=[
  "http://news.google.com/news?hl=ja&ned=us&ie=UTF-8&oe=UTF-8&output=rss",
  "http://rss.dailynews.yahoo.co.jp/fc/domestic/rss.xml",
  "http://sankei.jp.msn.com/rss/news/points.xml",
]
#############################################

require 'rss'
require 'active_record'
require 'nokogiri'
require 'mail'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'db/db.sqlite3'
)
unless ActiveRecord::Base.connection.table_exists? :rsssites
  ActiveRecord::Migration.create_table :rsssites do |t|
    t.string :url, :null => false
    t.string :last_get_date, :null => false
    t.timestamps
  end
end
class Rsssites < ActiveRecord::Base
end

Mail.defaults do
  delivery_method :sendmail
end

urls.each do |url|
  if Rsssites.find_by_url(url).nil?
    db = Rsssites.new
    db.url = url
    db.last_get_date = "2000-01-01 00:00:00 +0900"
  else
    db = Rsssites.find_by_url(url)
  end
  rss = RSS::Parser.parse(url)
  rss.items.each do |item|
    if !defined?(item.pubDate) or item.pubDate.nil?
      class << item
        def pubDate
          dc_date
        end
      end
    end
  end
  rss.items.sort{|a,b|a.pubDate <=> b.pubDate}.each do |item|
    if item.pubDate <= Time.parse(db.last_get_date)
      next
    else
      db.last_get_date = item.pubDate.to_s
    end
    mail = Mail.new do
      from  'rss@example.com'
      to    'rss@example.com'
    end
    mail.charset ='utf-8'
    mail.subject = item.title
    mail.body  = item.link + "\n\n\n" + Nokogiri::HTML(item.description).text
    mail.deliver
  end
  db.save
end
