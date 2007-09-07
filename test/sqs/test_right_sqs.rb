require File.dirname(__FILE__) + '/test_helper.rb'

class TestSqs < Test::Unit::TestCase

  GRANTEE_EMAIL_ADDRESS = 'fester@example.com'
  RIGHT_MESSAGE_TEXT    = 'Right test message'

  
  def setup
    @sqs = Rightscale::SqsInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
    @queue_name = 'right_sqs_test_awesome_queue'
      # for classes
    @s = Rightscale::Sqs.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
  end
  
  #---------------------------
  # Rightscale::SqsInterface
  #---------------------------

  def test_01_create_queue
    queue_url = @sqs.create_queue @queue_name
    assert queue_url[/http.*#{@queue_name}/], 'New queue creation fail'
  end

  def test_02_list_queues
    queues = @sqs.list_queues('right_')
    assert queues.size>0, 'Must more that 0 queues in list'
  end

  def test_03_set_and_get_queue_attributes
    queue_url = @sqs.queue_url_by_name(@queue_name)
    assert queue_url[/http.*#{@queue_name}/], "#{@queue_name} must exist!"
    assert @sqs.set_queue_attributes(queue_url, 'VisibilityTimeout', 111), 'Set_queue_attributes fail'
    sleep 10 # Amazon needs some time to change attribute
    assert_equal '111', @sqs.get_queue_attributes(queue_url)['VisibilityTimeout'], 'New VisibilityTimeout must be equal to 111'
  end
  
  def test_04_set_and_get_visibility_timeout
    queue_url = @sqs.queue_url_by_name(@queue_name)
    assert @sqs.set_visibility_timeout(queue_url, 222), 'Set_visibility_timeout fail'
    sleep 10 # Amazon needs some time to change attribute
    assert_equal 222, @sqs.get_visibility_timeout(queue_url), 'Get_visibility_timeout must return to 222'
  end
  
  def test_05_add_test_remove_grant
    queue_url = @sqs.queue_url_by_name(@queue_name)
    assert @sqs.add_grant(queue_url, GRANTEE_EMAIL_ADDRESS, 'FULLCONTROL'), 'Add grant fail'
    grants_list = @sqs.list_grants(queue_url, GRANTEE_EMAIL_ADDRESS)
    assert grants_list.size>0, 'List_grants must return at least 1 record for user #{GRANTEE_EMAIL_ADDRESS}'
    assert @sqs.remove_grant(queue_url, GRANTEE_EMAIL_ADDRESS, 'FULLCONTROL'), 'Remove_grant fail'
  end
  
  def test_06_send_message
    queue_url = @sqs.queue_url_by_name(@queue_name)
      # send 5 messages for the tests below
    assert @sqs.send_message(queue_url, RIGHT_MESSAGE_TEXT)
    assert @sqs.send_message(queue_url, RIGHT_MESSAGE_TEXT)
    assert @sqs.send_message(queue_url, RIGHT_MESSAGE_TEXT)
    assert @sqs.send_message(queue_url, RIGHT_MESSAGE_TEXT)
    assert @sqs.send_message(queue_url, RIGHT_MESSAGE_TEXT)
  end
  
  def test_07_get_queue_length
    queue_url = @sqs.queue_url_by_name(@queue_name)
    assert_equal 5, @sqs.get_queue_length(queue_url), 'Queue must have 5 messages'
  end

  def test_08_receive_message
    queue_url = @sqs.queue_url_by_name(@queue_name)
    r_message = @sqs.receive_message(queue_url, 1)
    assert_equal RIGHT_MESSAGE_TEXT, r_message[:body], 'Receive message get wron message text'
    p_message = @sqs.peek_message(queue_url, r_message[:id])
    assert_equal r_message[:body], p_message[:body], 'Received and Peeked messages must be equal'
    assert @sqs.change_message_visibility(queue_url, r_message[:id], 0), 'Change_message_visibility fail'
  end
  
  def test_09_delete_message
    queue_url = @sqs.queue_url_by_name(@queue_name)
    message = @sqs.receive_message(queue_url)
    assert @sqs.delete_message(queue_url, message[:id]), 'Delete_message fail'
    assert @sqs.pop_message(queue_url), 'Pop_message fail'
  end
  
  def test_10_clear_and_delete_queue
    queue_url = @sqs.queue_url_by_name(@queue_name)
    assert_raise(Rightscale::AwsError) { @sqs.delete_queue(queue_url) }
## oops, force_clear_queue does not work any more - amazon expects for 60 secs timeout between 
## queue deletion and recreation...
##    assert @sqs.force_clear_queue(queue_url), 'Force_clear_queue fail'
    assert @sqs.clear_queue(queue_url), 'Clear_queue fail'
    assert @sqs.delete_queue(queue_url), 'Delete_queue fail'
  end
  
  #---------------------------
  # Rightscale::Sqs classes
  #---------------------------

  def test_20_sqs_create_delete_queue
    assert @s, 'Rightscale::Sqs must exist'
      # get queues list
    queues_size = @s.queues.size
      # create new queue
    queue  = @s.queue("#{@queue_name}_20", true)
      # check that it is created
    assert queue.is_a?(Rightscale::Sqs::Queue)
      # check that amount of queues has increased
    assert_equal queues_size + 1, @s.queues.size
      # delete queue
    assert queue.delete
  end
  
  def test_21_queue_create
      # create new queue
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_21", true)
      # check that it is created
    assert queue.is_a?(Rightscale::Sqs::Queue)
  end
  
  def test_22_queue_attributes
    sleep 10
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_21", false)
      # get a list of attrinutes
    attributes = queue.get_attribute
    assert attributes.is_a?(Hash) && attributes.size>0
      # get attribute value and increase it by 10
    v = (queue.get_attribute('VisibilityTimeout').to_i + 10).to_s
      # set attribute
    assert queue.set_attribute('VisibilityTimeout', v)
      # wait a bit
    sleep 10
      # check that attribute has changed
    assert_equal v, queue.get_attribute('VisibilityTimeout')
      # get queue visibility timeout
    assert v.to_i, queue.visibility
      # change it 
    queue.visibility += 10
      # make sure that it is changed
    assert v.to_i + 10, queue.visibility
  end
  
  def test_23_grantees
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_21", false)
      # get a list of grantees
    grantees = queue.grantees
      # well, queue must exist at least some seconds before we could add grantees to it....
      # otherwise we get "Queue does not exists" message. Hence we use the queue
      # has been created at previous step.
      #
      # create new grantee
    grantee = Rightscale::Sqs::Grantee.new(queue, GRANTEE_EMAIL_ADDRESS)
    assert grantee.perms.empty?
      # grant perms
    assert grantee.grant('FULLCONTROL')
    assert grantee.grant('RECEIVEMESSAGE')
    assert_equal 2, grantee.perms.size
      # make sure that amount of grantees has increased
    assert grantees.size < queue.grantees.size
      # revoke perms
    assert grantee.revoke('RECEIVEMESSAGE')
    assert_equal 1, grantee.perms.size
      # remove grantee
    assert grantee.drop
    # Don't test this - just for cleanup purposes
    queue.delete
  end
  
  def test_24_send_size
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_24", true)
      # send 5 messages
    assert queue.push('a1')
    assert queue.push('a2')
    assert queue.push('a3')
    assert queue.push('a4')
    assert queue.push('a5')
      # check queue size
    assert_equal 5, queue.size
      # send one more
    assert queue.push('a6')
      # check queue size again
    assert_equal 6, queue.size
  end
  
  def test_25_message_receive_pop_peek_delete
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_24", false)
      # get queue size
    size = queue.size
      # get first message
    m1 = queue.receive(10)
    assert m1.is_a?(Rightscale::Sqs::Message)
      # pop second message
    m2 = queue.pop
    assert m2.is_a?(Rightscale::Sqs::Message)
      # make sure that queue size has decreased
    assert_equal size-1, queue.size
      # peek message 1
    m1p = queue.peek(m1.id)
    assert m1p.is_a?(Rightscale::Sqs::Message)
    assert_equal m1.id,   m1p.id
    assert_equal m1.body, m1p.body
      # change message visibility
    assert m1.visibility = 30
      # delete messsage
    assert m1.delete
      # make sure that queue size has decreased again
    assert_equal size-2, queue.size
  end
  
  def test_26
    queue = Rightscale::Sqs::Queue.create(@s, "#{@queue_name}_24", false)
      # lock message 
    queue.receive(100)
      # clear queue
    assert queue.clear 
      # queue size is greater than zero
    assert queue.size>0
    queue.push('123456')
    assert_raise(Rightscale::AwsError) { queue.delete }
    assert queue.delete(true)
  end

end
