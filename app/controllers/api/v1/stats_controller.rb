module Api
  module V1
    class StatsController < BaseController
      def index
        render json: {
          study_streak:    study_streak,
          last_session:    last_session,
          next_review:     next_review
        }
      end

      private

      def review_logs
        ReviewLog
          .joins(card_review: { card: { category: :deck } })
          .where(decks: { user: current_user })
      end

      def study_streak
        dates = review_logs
          .order(reviewed_at: :desc)
          .pluck(:reviewed_at)
          .map { |d| d.to_date }
          .uniq

        streak = 0
        today = Date.current

        dates.each_with_index do |date, i|
          expected = today - i.days
          break unless date == expected
          streak += 1
        end

        streak
      end

      def last_session
        last_log = review_logs.order(reviewed_at: :desc).first
        return nil unless last_log

        session_date = last_log.reviewed_at.to_date
        session_logs = review_logs.where("DATE(reviewed_at) = ?", session_date)

        {
          date:         last_log.reviewed_at,
          cards_count:  session_logs.count,
          success_rate: (session_logs.where("quality >= 4").count.to_f / session_logs.count * 100).round(1)   }
      end

      def next_review
        due_cards = Card
          .joins(category: :deck)
          .left_joins(:card_reviews)
          .where(decks: { user: current_user })
          .where(
            "card_reviews.id IS NULL OR (card_reviews.user_id = ? AND card_reviews.next_review_at <= ?)",
            current_user.id, Time.current
          )

        category_counts = due_cards
          .group("categories.id", "categories.name", "decks.id", "decks.name")
          .count

        return nil if category_counts.empty?

        top = category_counts.max_by { |_, count| count }
        key, count = top
        category_id, category_name, deck_id, deck_name = key

        {
          deck_id:       deck_id,
          deck_name:     deck_name,
          category_id:   category_id,
          category_name: category_name,
          due_count:     count
        }
      end
    end
  end
end