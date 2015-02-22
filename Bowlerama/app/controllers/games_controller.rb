class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy]

  # GET /games
  # GET /games.json
  def index
    @games = Game.all
  end

  # GET /games/1
  # GET /games/1.json
  def show
  end

  # GET /games/new
  def new
    @game = Game.new
  end

  # GET /games/1/edit
  def edit
  end

  # POST /games
  # POST /games.json
  def create
    @game = Game.new(game_params)

    @bowled_pins = 0
    @pins_left = 10
    @game.current_frame = 1
    @game.frame_stroke = 1
    @game.total_score = 0

    respond_to do |format|
      if @game.save
        format.html { redirect_to @game, notice: 'Game was successfully created.' }
        format.json { render :show, status: :created, location: @game }
      else
        format.html { render :new }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /games/1
  # PATCH/PUT /games/1.json
  def update
    respond_to do |format|
      if @game.update(game_params)
        format.html { redirect_to @game, notice: 'Game was successfully updated.' }
        format.json { render :show, status: :ok, location: @game }
      else
        format.html { render :edit }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /games/1
  # DELETE /games/1.json
  def destroy
    @game.destroy
    respond_to do |format|
      format.html { redirect_to games_url, notice: 'Game was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def bowl
    @game.resetPinsIfNecessary

    # Create new frame if necessary
    if @game.frame_stroke == 2
      @game.resetPins
      @game.incrementFrameCount
      @frame = @game.frames.create(frame_number: @game.current_frame)
    end

    # Handle first stroke for all frames
    if @game.frame_stroke == 1 && @game.current_frame <= 10
      @bowled_pins = randomizePinCount( 0, 10 )
      @pins_left = @bowled_pins - 10
    
    # Handle second stroke for frames 1 through 9
    elsif @game.frame_stroke == 2 && @game.current_frame < 10
      @pins_left = @bowled_pins - 10
      @pins_left = randomizePinCount( 0, @pins_left )
      @bowled_pins = @pins_left

    # Handle second and third stroke for frame 10  
    elsif @game.frame_stroke != 1 && @game.current_frame == 10
      if @game.isLastTurnStrike()  || @game.isLastTurnSpare()
        @bowled_pins = randomizePinCount( 0, 10 )
      else
        @pins_left = @bowled_pins - 10
        @pins_left = randomizePinCount( 0, @pins_left )
        @bowled_pins = @pins_left
      end
    end

    @game.markScorecard

    respond_to do |format|
      if @game.update(game_params)
        format.html { redirect_to @game, notice: 'Game was successfully updated.' }
        format.json { render :show, status: :ok, location: @game }
      else
        format.html { render :edit }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  def reset
    @game.destroy
    respond_to do |format|
      format.html { redirect_to games_url, notice: 'Game was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_game
      @game = Game.find(params[:id])
    end

    def randomizePinCount ( start_value, finish_value)
      return rand( start_value..finish_value )
    end

    def incrementFrameCount
      @game.current_frame += 1
    end

    def advanceFrameStroke
      if @game.frame_stroke == 1
        @game.frame_stroke == 2
      else
        @game.frame_stroke == 1
      end
    end

    def markScorecard (frame_to_score)
      # Handle Strikes and Spares for frames 1 through 9
      if @game.current_frame < 10 && @pins_left == 0
        if @game.frame_stroke == 1
          @game.frame.first_stroke = "X"
        elsif @frame_stroke == 2 
          @game.frame.second_strokes = "/"
        end
      
      # Handle Strikes and Spares for frame 10
      elsif @game.current_frame == 10 && @pins_left == 0
        if @game.frame_stroke == 1 
          @game.frame.first_stroke = "X"
        elsif @frame_stroke == 2
          if isLastTurnStrike
            @game.frame.second_strokes = "X"
          else
            @game.frame.second_strokes = "/"
          end
        elsif @game.frame_stroke == 3
          if isLastTurnStrike || isLastTurnSpare
            @game.frame.extra_stroke = "X"
          else
            @@game.frame.extra_stroke = "/"
          end
        end
      
      # Handle Zero pins bowled
      elsif @bowled_pins == 0
        if @game.frame_stroke == 1
          @game.frame.first_stroke = "-"
        elsif @game.frame_stroke == 2
          @game.frame.second_strokes = "-"
        elsif @game.frame_stroke == 3
          @game.frame.extra_stroke = "-"
        end
      
      # Handle all other strokes
      else
        if @game.frame_stroke == 1 
          @game.frame.first_stroke = @bowled_pins.to_s
        elsif @game.frame_stroke == 2
          @game.frame.second_strokes = @bowled_pins.to_s
        else
          @game.frame.extra_stroke = @bowled_pins.to_s
      end
    end

    def resetPinsIfNecessary
      if ( @game.frame_stroke == 2 && @game.current_frame < 10 ) || @game.isLastTurnStrike || @game.isLastTurnSpare
        @pins_left = 10
        @bowled_pins = 0
      end
    end

    def isLastTurnStrike

    end

    def isLastTurnSpare

    end

    def calculateTotalScore
      # Calculate the sum of values in @frame_scores
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def game_params
      params.require(:game).permit(:current_frame, :frame_stroke, :total_score)
    end
end
