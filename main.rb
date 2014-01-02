require 'rubygems'
require 'sinatra'
require 'pry'

set :sessions, true
BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_VALUE = 500

helpers do
  def calculate_total(cards)
    arr = cards.map { |e| e[1] }

    total = 0
    arr.each do |value|
      if value == 'A'
        total += 11
      elsif value.to_i == 0 # J, Q, K
        total += 10
      else
        total += value.to_i
      end
    end

    # correct for aces
    arr.select { |e| e == 'A' }.count.times do
      total -= 10 if total > BLACKJACK_AMOUNT
    end

    total
  end # end calculate_total method

   def card_image(card)
          suit = case card[0]
                      when 'H' then 'Hearts'
                      when 'D' then 'Diamonds'
                      when 'S' then  'Spades'
                      when 'C' then  'Clubs'
                    end

        value = card[1]
        if %w(J Q K A).include?(value)
          value = case card[1]
                        when 'J' then 'jack'
                        when 'Q' then 'queen'
                        when 'K' then  'king'
                        when 'A' then  'ace'
                      end
        end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'/>"
  end # end image string method

  def winner!(msg)
    @winner = "<strong>#{session[:player_name]} wins.</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
    session[:purse] += session[:bet_amount]
  end

  def loser!(msg)
    @loser = "<strong>Sorry #{session[:player_name]} lost.</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
    session[:purse] -= session[:bet_amount]
  end

  def tie!(msg)
    @winner = "<strong>It's a tie</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
  end
end # end helpers

before do
  @show_hit_or_stay_buttons = true
  @blackjack = false
  @bust = false
  @play_again = false
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:purse] = INITIAL_POT_VALUE
  erb :new_player
end

post '/new_player' do
  user_input = params[:player_name]

  if user_input.strip.empty?
    @error = "Please input name"
    halt erb(:new_player)
  end

  # problem here with the backslash character for white space
  if (params[:player_name] =~ /^[a-z A-Z]+$/).nil?
    @error = "Please use only letter when writing your name"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  # redirect '/game'
  redirect '/place_bet'
end

get '/place_bet' do
  session[:bet_amount] = nil
  erb :place_bet
end

post '/place_bet' do
  if (params[:bet_amount] =~ /^\d+$/).nil?
    @error = "Must be a digit"
    halt erb(:place_bet)
  elsif params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "Must make a bet."
    halt erb(:place_bet)
  elsif params[:bet_amount].to_i <= 0
    @error = "Bet must be a number greater than 0"
    halt erb(:place_bet)
  elsif params[:bet_amount].to_i > session[:purse].to_i
    @error = "Bet amount can not be greater than what you have."
    halt erb(:place_bet)
  else #happy path
    session[:bet_amount] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]
  @show_dealer_whole_card = false

  suits = ['H', 'D', 'S', 'C']
  cards = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(cards).shuffle!

  session[:player_cards] = []
  session[:dealer_cards] = []

  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop

  erb :game
end

post '/game/player/hit' do
  @show_dealer_whole_card = false
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit blackjack!")
  end
  if player_total > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} busted at #{player_total}.")
  end
  erb :game, layout: false
end

post '/game/player/stay' do
  # Not sure where this line comes from, the @success will not be available in redirect.
  @success = "#{session[:player_name]} has chosen to stay"
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  # decision tree
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK_AMOUNT
    loser!("Dealer hit blackjack, dealer wins!")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("Dealer busts at #{dealer_total}")
  elsif dealer_total >= DEALER_MIN_HIT
    # dealer stays
    redirect 'game/compare/'
  else
    # dealer hits
    @show_dealer_hit_button = true
  end
  erb :game,layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect 'game/dealer'
end

get '/game/compare/' do
  @show_dealer_hit_button = false
  @show_hit_or_stay_buttons = false

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total > player_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and
      the dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and
      the dealer stayed at #{dealer_total}.")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at
      #{player_total}.")
  end

  erb :game, layout: false
end # route end
