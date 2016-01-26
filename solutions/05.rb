class Result
  attr_reader :message, :result

  def initialize(message, return_code, result = nil)
    @message = message
    @status = return_code
    @result = result
  end

  def success?
    @status
  end

  def error?
    not @status
  end
end

class CommitObject
  attr_reader :name, :object
  attr_accessor :for_deletion

  def initialize(name, object = nil)
    @name = name
    @object = object
    @for_deletion = false
  end

  def for_deletion?
    @for_deletion
  end

  def ==(other)
    @name == other.name
  end
end

class CommitEntry
  attr_reader :hash, :date, :message
  attr_accessor :objects

  def initialize(message, objects)
    @message = message
    @date = Time.now
    @hash = Digest::SHA1.hexdigest("#{formatted_date}#{@message}")
    @objects = objects
  end

  def ==(other)
    @hash == other.hash
  end

  def to_s
    "Commit #{@hash}\nDate: #{formatted_date}\n\n\t" \
    "#{@message}"
  end

  private

  def formatted_date
    @date.strftime('%a %b %d %H:%M %Y %z')
  end
end

class Branch
  attr_reader :name
  attr_accessor :staged, :commits, :items

  def initialize(branch_name, object_store, branch_items = [], commits = [])
    @name = branch_name
    @object_store = object_store
    @items = branch_items
    @staged = []
    @commits = commits
  end

  def ==(other)
    @name == other.name
  end

  def create(branch_name)
    if @object_store.repository.any? { |branch| branch.name == branch_name }
      Result.new("Branch #{branch_name} already exists.", false)
    else
      @object_store.repository.push(Branch.new(branch_name, @object_store,
                                               items.clone, commits.clone))
      Result.new("Created branch #{branch_name}.", true,
                 @object_store.repository.last)
    end
  end

  def get_branch_index(branch_name)
    @object_store.repository.index { |branch| branch.name == branch_name }
  end

  def checkout(branch_name)
    branch_index = get_branch_index(branch_name)
    if branch_index.nil?
      Result.new("Branch #{branch_name} does not exist.", false)
    else
      @object_store.current_branch = branch_name
      Result.new("Switched to branch #{branch_name}.", true,
                 @object_store.repository[branch_index])
    end
  end

  def remove(branch_name)
    if @object_store.current_branch == branch_name
      return Result.new('Cannot remove current branch.', false)
    end
    branch_index = get_branch_index(branch_name)
    if branch_index.nil?
      Result.new("Branch #{branch_name} does not exist.", false)
    else
      @object_store.repository.delete_at(branch_index)
      Result.new("Removed branch #{branch_name}.", true)
    end
  end

  def list
    branch_names = @object_store.repository.collect(&:name)
    branch_names.sort!.map! do |name|
      name == @object_store.current_branch ? "* #{name}" : "  #{name}"
    end
    Result.new(branch_names.join("\n"), true)
  end
end

class ObjectStore
  attr_reader :repository
  attr_accessor :current_branch

  def initialize
    @repository = [Branch.new('master', self)]
    @current_branch = 'master'
  end

  def self.init(&block)
    object_store = ObjectStore.new
    object_store.instance_eval &block if block_given?
    object_store
  end

  def head
    if branch.commits.empty?
      Result.new("Branch #{branch.name} does not have any commits yet.", false)
    else
      commit = branch.commits.first.dup
      commit.objects = branch.items.map(&:object)
      Result.new("#{branch.commits.first.message}", true, commit)
    end
  end

  def add(name, object)
    remove(name) if branch.items.include?(CommitObject.new(name))
    branch.staged.push(CommitObject.new(name, object))
    Result.new("Added #{name} to stage.", true, object)
  end

  def log
    if branch.commits.empty?
      message = "Branch #{@current_branch} does not have any commits yet."
      Result.new(message, false)
    else
      message = branch.commits.map(&:to_s).join("\n\n")
      Result.new(message, true, branch.commits)
    end
  end

  # case 1: cleans up staged array on commit by either
  # removing or adding items to the repository
  # case 2: rolls back to a previous commit,
  # reversing each commit command along the way
  def sweep(object, command = :commit)
    if (object.for_deletion? && command != :rollback) ||
       (!object.for_deletion? && command == :rollback)
      branch.items.delete(object)
    else
      branch.items.push(object)
    end
  end

  def cleanup(branch, message)
    # add the staged items to the repository
    branch.staged.each { |object| sweep(object) }
    branch.commits.insert(0, CommitEntry.new(message, branch.staged.clone))
    branch.staged.clear
  end

  def commit(message)
    if branch.staged.empty?
      return Result.new('Nothing to commit, working directory clean.', false)
    end
    length = branch.staged.length
    cleanup(branch, message)
    Result.new("#{message}\n\t#{length} objects changed", true,
               head.result)
  end

  def remove(name)
    for_deletion = object_exists?(name)
    if for_deletion.equal? nil
      Result.new("Object #{name} is not committed.", false)
    else
      for_deletion.for_deletion = true
      branch.staged.push(for_deletion)
      Result.new("Added #{name} for removal.", true, for_deletion.object)
    end
  end

  def checkout(commit_hash)
    commit_index = branch.commits.index { |entry| entry.hash == commit_hash }
    if commit_index.nil?
      return Result.new("Commit #{commit_hash} does not exist.", false)
    end
    0.upto(commit_index - 1) do |index|
      branch.commits[index].objects.map { |entry| sweep(entry, :rollback) }
    end
    branch.commits = branch.commits.take(commit_index + 1).reverse
    Result.new("HEAD is now at #{head.result.hash}.", true, head.result)
  end

  def object_exists?(name)
    branch.items.find { |commit_object| commit_object.name == name }
  end

  def branch
    @repository.find { |branch| branch.name == @current_branch }
  end

  def get(object_name)
    commit_object = branch.items.find { |item| item.name == object_name }
    if commit_object.nil?
      Result.new("Object #{object_name} is not committed.", false)
    else
      Result.new("Found object #{object_name}.", true, commit_object.object)
    end
  end
end
