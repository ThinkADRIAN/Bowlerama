class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy, :bowl, :reset]

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

    #@game.bowled_pins = 0
    #@game.pins_left = 10
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
    #@game = Game.new(game_params)
    @game = Game.new

    #@game.bowled_pins = 0
    #@game.pins_left = 10
    @game.current_frame = 1
    @game.frame_stroke = 1
    @game.total_score = 0

    respond_to do |format|
      if @game.save 
        format.html { redirect_to action: "index", notice: 'Game was successfully created.' }
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
    if !@game.isGameOver

      @game.rollBall

      @game.markScorecard

      respond_to do |format|
        if @game.save
          format.html { redirect_to action: "show", notice: 'Game was successfully updated.' }
          format.json { render :show, status: :ok, location: games_url }
        else
          format.html { render :edit }
          format.json { render json: @game.errors, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
          format.html { redirect_to games_url, notice: 'Game is over.  Your final score: ' + @game.total_score.to_s }
          format.json { render :show, status: :ok, location: games_url }
      end
    end
  end

  def reset
    @game.clearFrames

    respond_to do |format|
      if @game.save
        format.html { redirect_to action: "show", notice: 'Game was successfully reset.' }
        format.json { head :no_content }
      else
        format.html { render :edit }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
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
end