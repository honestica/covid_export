class StandardSurvey::SetStatus
  def self.call(standard_survey)
    new(standard_survey).call
  end

  def initialize(standard_survey)
    @standard_survey = standard_survey
  end

  attr_reader :standard_survey

  def call
    return set_red_status if red_status?
    return set_orange_status if orange_status?
    return set_green_status if green_status?

    set_default_status
  end

  private

    def patient
      standard_survey.patient
    end

    def oldest_unanswered_standard_survey_sent_at
      latests_pending_standard_surveys.take&.created_at
    end

    def latests_pending_standard_surveys
      patient.standard_surveys.pending.where("standard_surveys.created_at > ?", standard_survey.created_at)
        .order(created_at: :asc)
    end

    def set_default_status
      standard_survey.update!(status: ::StandardSurvey::STATUS_YELLOW)
      Patient::SetAttributesFromStandardSurvey.call(patient, standard_survey)
    end

    def red_conditions
      conditions = [
        standard_survey.breathing_difficulty_borg_scale.to_f > 5.0,
        standard_survey.chest_pain_new?,
        high_breathing_difficulty_borg_scale_variation
      ]

      conditions << standard_survey.general_condition_3? if standard_survey.opt_standard_survey_general_condition?
      conditions << standard_survey.stress_level_4? if standard_survey.opt_standard_survey_stress_level?
      conditions << standard_survey.diarrhea_vomiting_4? if standard_survey.opt_standard_survey_diarrhea_vomiting?

      conditions
    end

    def red_status?
      red_conditions.any?
    end

    def set_red_status
      standard_survey.update!(status: ::StandardSurvey::STATUS_RED)
      Patient::SetAttributesFromStandardSurvey.call(patient, standard_survey)
      action_needed!
    end

    def orange_conditions
      conditions = [
        standard_survey.body_temperature.to_f > 40,
        standard_survey.breathing_difficulty_borg_scale.to_f > 3.0,
        standard_survey.respiratory_rate_in_cycles_per_minute.to_i >= 22,
        !standard_survey.agreed_containment,
        standard_survey.chest_pain_caughing?,
        standard_survey.body_temperature.to_f > 39 && standard_survey.breathing_difficulty_borg_scale.to_f > 2.0,
      ]

      conditions << standard_survey.general_condition_2? if standard_survey.opt_standard_survey_general_condition?
      conditions << standard_survey.stress_level_3? if standard_survey.opt_standard_survey_stress_level?
      conditions << standard_survey.diarrhea_vomiting_3? if standard_survey.opt_standard_survey_diarrhea_vomiting?

      conditions
    end

    def orange_status?
      orange_conditions.any?
    end

    def set_orange_status
      standard_survey.update!(status: ::StandardSurvey::STATUS_ORANGE)
      Patient::SetAttributesFromStandardSurvey.call(patient, standard_survey)
      action_needed!
    end

    def green_status?
      [
        !standard_survey.cohabitants_recent_change,
        standard_survey.body_temperature.to_f < 38.5,
        standard_survey.breathing_difficulty_borg_scale.to_f <= 1.0,
        standard_survey.heartbeats_per_minute.to_i < 110,
        standard_survey.respiratory_rate_in_cycles_per_minute.to_i < 22,
        !standard_survey.recent_cold_chill,
        standard_survey.chest_pain_no?,
        standard_survey.agreed_containment
      ].all?
    end

    def set_green_status
      standard_survey.update!(status: ::StandardSurvey::STATUS_GREEN)
      Patient::SetAttributesFromStandardSurvey.call(patient, standard_survey)
    end

    def previous_completed_standard_survey
      standard_survey.previous_completed_standard_survey
    end

    def high_breathing_difficulty_borg_scale_variation
      return false unless previous_completed_standard_survey

      (standard_survey.breathing_difficulty_borg_scale.to_f - previous_completed_standard_survey.breathing_difficulty_borg_scale.to_f) > 2.0
    end

    def action_needed!
      standard_survey.update!(action_needed: true)
      patient.update!(action_needed: true)
    end
end