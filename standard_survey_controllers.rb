class StandardSurveysController < ApplicationController

  skip_before_action :verify_authenticity_token

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    @standard_survey = StandardSurvey.find_by!(public_token: params[:id])
  end

  def edit
    @form = UpdateStandardSurveyForm.new(standard_survey: standard_survey, otp: params[:otp])
    standard_survey.eventually_set_first_opened_at!
    standard_survey.safely_track!(browser)
  end

  def update
    @form = UpdateStandardSurveyForm.new(standard_survey_params)
    @form.standard_survey = standard_survey

    if @form.submit
      redirect_to success_standard_survey_path(standard_survey.public_token)
    else
      render :edit
    end
  end

  def not_found
    render :not_found
  end

  private

    def standard_survey
      @_standard_survey ||= StandardSurvey.to_complete.find_by!(public_token: params[:id])
    end

    def standard_survey_params
      params.require(:update_standard_survey_form).permit(UpdateStandardSurveyForm::CONTROLLER_ATTRIBUTES)
    end

end