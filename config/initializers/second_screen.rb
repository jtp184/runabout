unless Rails.env.test?
  Rails.application.config.active_job.queue_adapter = :solid_queue
  Rails.application.config.solid_queue.connects_to = { database: { writing: :queue } }
end
