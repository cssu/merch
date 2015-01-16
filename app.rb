require 'sinatra'
require 'sinatra/param'
require 'json'
require 'google_drive'

# noinspection RubyStringKeysInHashInspection
PRODUCTS = {
    'Hoodie' => %w(black blue grey),
    'T-Shirt' => %w(black blue grey),
    'Travel Mug' => %w(white)
}

get '/' do
  'It\'s working!'
end

post '/reservations.json' do
  content_type :json

  param :name, String, required: true
  param :email, String, required: true
  param :product, String, required: true, in: PRODUCTS.keys
  param :colour, String
  param :size, String, in: %w(XS S M L XL)
  param :quantity, Integer, required: true

  key = OpenSSL::PKey::RSA.new ENV['CLIENT_KEY'].gsub(/\\n/, "\n") || raise('No CLIENT_KEY provided'), 'notasecret'
  client = Google::APIClient.new
  client.authorization = Signet::OAuth2::Client.new(
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience: 'https://accounts.google.com/o/oauth2/token',
      scope: %w(https://www.googleapis.com/auth/drive https://spreadsheets.google.com/feeds),
      issuer: ENV['SERVICE_EMAIL'],
      signing_key: key
  )
  client.authorization.fetch_access_token!
  session = GoogleDrive.login_with_oauth client.authorization.access_token
  spreadsheet = session.spreadsheet_by_key ENV['SHEET_KEY']
  ws = spreadsheet.worksheets.first

  # Add a new row to the sheet with the reservation info
  ws.list.push({
    :'Name' => params['name'],
    :'Email' => params['email'],
    :'Product' => params['product'],
    :'Colour' => params['colour'],
    :'Size' => params['size'],
    :'Quantity' => params['quantity']
  })

  # Attempt save
  if ws.save
    200
  else
    [500, 'Failed to save spreadsheet']
  end
end
