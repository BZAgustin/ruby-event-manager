# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(code)
  code.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  invalid = ['.', ' ', '(', ')', '-', '+']

  clean_number = number.split(//).reject { |chr| invalid.include?(chr) }.join

  return 'Invalid' if clean_number.length < 10 ||
                      clean_number.length > 11 ||
                      (clean_number.length == 11 && clean_number[0] != '1')

  return clean_number if clean_number.length == 10

  clean_number[1..]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

def check_highest(arr)
  item_count = arr.reduce(Hash.new(0)) do |hash, item|
    hash[item] += 1

    hash
  end

  max_k = 0
  max_v = 0

  item_count.each do |key, value|
    if value > max_v
      max_k = key
      max_v = value
    end
  end

  max_k
end

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
reg_hours = []
reg_days = []
weekdays = { 0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday',
             4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday' }

contents.each do |row|

  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  date = DateTime.strptime(row[:regdate], '%m/%d/%Y %H:%M')

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  reg_hours.push(date.hour)

  reg_days.push(date.wday)
end

puts "Most active registration time: #{check_highest(reg_hours)}:00 HS"

puts "Most active registration day: #{weekdays[check_highest(reg_days)]}"
