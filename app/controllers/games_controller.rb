class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy, :bowl]

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

    @game.bowled_pins = 0
    @game.pins_left = 10
    @game.current_frame = 1
    @game.frame_stroke = 1
    @game.total_score = 0
  end

  # GET /games/1/edit
  def edit
  end

  # POST /games
  # POST /games.json
  def create
    @game = Game.new(game_params)

    respond_to do |format|
      if @game.save 
        @frame = @game.frames.create(frame_number: @game.current_frame)

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
    if !isGameOver

      resetPinsIfNecessary

      # Handle first stroke for all frames
      if @game.frame_stroke == 1 && @game.current_frame <= 10
        @game.bowled_pins = randomizePinCount( 0, 10 )
        @game.pins_left = 10 - @game.bowled_pins
      
      # Handle second stroke for frames 1 through 9
      elsif @game.frame_stroke == 2 && @game.current_frame < 10
        @game.bowled_pins = randomizePinCount( 0, @game.pins_left )
        @game.pins_left = @game.pins_left - @game.bowled_pins

      # Handle second and third stroke for frame 10  
      elsif @game.frame_stroke != 1 && @game.current_frame == 10
        if isLastTurnStrike?()  || isLastTurnSpare?()
          @game.bowled_pins = randomizePinCount( 0, 10 )
          @game.pins_left = 10 - @game.bowled_pins
        else
          @game.bowled_pins = randomizePinCount( 0, 10 )
          @game.pins_left = 10 - @game.bowled_pins
        end
      end

      markScorecard

      respond_to do |format|
        if @game.save
          format.html { redirect_to games_url, notice: 'Game was successfully updated.' }
          format.json { render :show, status: :ok, location: games_url }
        else
          format.html { render :edit }
          format.json { render json: @game.errors, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
          format.html { redirect_to games_url, notice: 'Game is over.' }
          format.json { render :show, status: :ok, location: games_url }
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

    # Never trust parameters from the scary internet, only allow the white list through.
    def game_params
      params.require(:game).permit(:current_frame, :frame_stroke, :total_score, 
        frames_attributes: [:first_stroke , :second_stroke, :extra_stroke])
    end

    def resetPinsIfNecessary
      if ( @game.frame_stroke == 1 && @game.current_frame < 10 ) || isLastTurnStrike? || isLastTurnSpare?
        @pins_left = 10
        @bowled_pins = 0
      end
    end

    def randomizePinCount( start_value, finish_value )
      return rand( start_value..finish_value )
    end


    def incrementFrameCount
      if @game.current_frame < 10
        @game.current_frame += 1
        @frame = @game.frames.create(frame_number: @game.current_frame)
      end
    end

    def advanceFrameStroke
      if @game.frame_stroke == 1
        @game.frame_stroke = 2
      else
        @game.frame_stroke = 1
      end
    end

    def endGame
      @game.frame_stroke = -1
    end

    def markScorecard
      # Handle Strikes and Spares for frames 1 through 9
      if @game.current_frame < 10 && @game.pins_left == 0
        if @game.frame_stroke == 1
          @game.frames.where(frame_number: @game.current_frame).update_all(first_stroke: "X")
        elsif @game.frame_stroke == 2
          @game.frames.where(frame_number: @game.current_frame).update_all(second_stroke: "/")
        end
        @game.frame_stroke = 1
        incrementFrameCount
      # Handle Strikes and Spares for frame 10
      elsif @game.current_frame == 10 && @pins_left == 0
        if @game.frame_stroke == 1
          @game.frames.where(frame_number: @game.current_frame).update_all(first_stroke: "X")
          incrementFrameCount
        elsif @game.frame_stroke == 2
          if isLastTurnStrike?
            @game.frames.where(frame_number: @game.current_frame).update_all(second_stroke: "X")
          else
            @game.frames.where(frame_number: @game.current_frame).update_all(second_stroke: "/")
          end
          endGame
        elsif @game.frame_stroke == 3
          if isLastTurnStrike? || isLastTurnSpare?
            @game.frames.where(frame_number: @game.current_frame).update_all(extra_stroke: "X")
          else
            @game.frames.where(frame_number: @game.current_frame).update_all(extra_stroke: "/")
          end
          endGame
        end
      
      # Handle Zero pins bowled
      elsif @game.bowled_pins == 0
        if @game.frame_stroke == 1
          @game.frames.where(frame_number: @game.current_frame).update_all(first_stroke: "-")
          advanceFrameStroke
        elsif @game.frame_stroke == 2
          @game.frames.where(frame_number: @game.current_frame).update_all(second_stroke: "-")
          advanceFrameStroke
          incrementFrameCount
        elsif @game.frame_stroke == 3
          @game.frames.where(frame_number: @game.current_frame).update_all(extra_stroke: "-")
          endGame
        end
      # Handle all other strokes
      else
        if @game.frame_stroke == 1 
          @game.frames.where(frame_number: @game.current_frame).update_all(first_stroke: @game.bowled_pins)
          advanceFrameStroke
        elsif @game.frame_stroke == 2
          @game.frames.where(frame_number: @game.current_frame).update_all(second_stroke: @game.bowled_pins)
          advanceFrameStroke
          incrementFrameCount
          if @game.current_frame == 10
            endGame
          end
        else
          endGame
        end
      end
    end

    def isLastTurnStrike?
      isStrike?(@game.current_frame-1)
    end

    def isLastTurnSpare?
      isSpare?(@game.current_frame-1)
    end

    def isStrike?(frame_to_check)
      @game.frames.where(frame_number: frame_to_check, first_stroke: "X") ||
      @game.frames.where(frame_number: frame_to_check, second_stroke: "X")
    end

    def isSpare?(frame_to_check)
      @game.frames.where(frame_number: frame_to_check, second_stroke: "/") || 
      @game.frames.where(frame_number: frame_to_check, extra_stroke: "/")
    end

    def calculateTotalScore
      # Calculate the sum of values in @frame_scores
    end

    def isGameOver
      @game.frame_stroke == -1
    end
end