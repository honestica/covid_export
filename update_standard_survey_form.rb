class UpdateStandardSurveyForm < BaseForm

  CONTROLLER_ATTRIBUTES = StandardSurvey::OPTIONAL_ATTRIBUTES + [
    :otp,
    :body_temperature,
    :cohabitants_recent_change,
    :breathing_difficulty_borg_scale,
    :heartbeats_per_minute,
    :chest_pain,
    :agreed_containment,
    :agreed_containment_comment,
    :respiratory_rate_in_cycles_per_minute,
    :recent_cold_chill
  ].freeze

  attr_accessor(
    *([:standard_survey] + CONTROLLER_ATTRIBUTES)
  )

  validates_presence_of :standard_survey, :otp, :body_temperature, :breathing_difficulty_borg_scale, :heartbeats_per_minute, :respiratory_rate_in_cycles_per_minute, :chest_pain

  validates_inclusion_of :cohabitants_recent_change, :agreed_containment, :recent_cold_chill, in: [true, false]

  validate :valid_otp
  validate :valid_optional_attributes

  def submit
    standard_survey.update!(number_of_submissions: (standard_survey.number_of_submissions || 0) + 1)

    return false unless valid?

    standard_survey.attributes = standard_survey_attributes

    if standard_survey.save
      standard_survey.set_status!

      return true
    end

    errors.merge!(standard_survey.errors)

    false
  end

  def total_steps
    8 + optional_steps
  end

  private

    def standard_survey_attributes
      {
        body_temperature: filtered_body_temperature,
        cohabitants_recent_change: cohabitants_recent_change,
        breathing_difficulty_borg_scale: breathing_difficulty_borg_scale,
        heartbeats_per_minute: heartbeats_per_minute,
        chest_pain: chest_pain,
        agreed_containment: agreed_containment,
        agreed_containment_comment: agreed_containment_comment,
        respiratory_rate_in_cycles_per_minute: respiratory_rate_in_cycles_per_minute,
        recent_cold_chill: recent_cold_chill,
        general_condition: general_condition,
        stress_level: stress_level,
        diarrhea_vomiting: diarrhea_vomiting,
        completed_at: DateTime.current
      }
    end

    def boolean_attributes
      [
        :cohabitants_recent_change,
        :agreed_containment,
        :recent_cold_chill
      ]
    end

    def valid_otp
      return if standard_survey.nil?

      errors.add(:otp, :invalid) unless standard_survey.patient.verify_otp(otp)
    end

    def filtered_body_temperature
      body_temperature.to_s.gsub(',', '.')
    end

    def valid_optional_attributes
      StandardSurvey::OPTIONAL_ATTRIBUTES.each { |key| valid_optional_attribute(key) }
    end

    def valid_optional_attribute(key)
      return unless standard_survey.public_send("opt_standard_survey_#{key}?")

      errors.add(key, :required) if self.public_send(key).blank?
    end

    def optional_steps
      StandardSurvey::OPTIONAL_ATTRIBUTES.map { |key| standard_survey.public_send("opt_standard_survey_#{key}?") }.count(true)
    end

end