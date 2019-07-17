#
# Ruby automated mazebot racer example
#
# Can you write a program that finishes the race?
#
require "net/http"
require "json"

class Solver

  STARTING_MARKER = 'A'
  ENDING_MARKER   = 'B'
  OPEN_MARKER     = ' '
  WALL_MARKER     = 'X'

  NORTH   = 'N'
  SOUTH   = 'S'
  EAST    = 'E'
  WEST    = 'W'

  attr_reader :maze, :solutions

  def initialize(maze)
    @maze = maze
    @solutions = []
    find_solutions(@maze['startingPosition'])
  end

  def shortest_solution
    @solutions.sort_by { |solution| solution.length }.first
  end

  private

  def find_solutions(current_position, path='', last_point=[])

    # Ensure the position is within bounds
    return nil unless current_position[1] >= 0 and current_position[1] < @maze['map'].length
    return nil unless current_position[0] >= 0 and current_position[0] < @maze['map'][current_position[1]].length

    # What's currently at this location in the maze
    marker = @maze['map'][current_position[1]][current_position[0]]

    case marker
    when ENDING_MARKER
      solution_found(path)
    when WALL_MARKER
      nil
    when STARTING_MARKER, OPEN_MARKER
      traverse_maze(current_position, path, last_point)
    else
      traverse_maze(current_position, path, last_point) if path.length < marker
    end

  end

  def traverse_maze(current_position, path, last_point)
    # Mark the current location so that we don't check this path again
    @maze['map'][current_position[1]][current_position[0]] = path.length

    # An array of cardinal directions around the current location in the maze
    directions = [
      { point: [current_position[0],   current_position[1]-1], direction: NORTH },
      { point: [current_position[0],   current_position[1]+1], direction: SOUTH },
      { point: [current_position[0]+1, current_position[1]  ], direction: EAST  },
      { point: [current_position[0]-1, current_position[1]  ], direction: WEST  }
    ]

    # Array of created threads
    threads = []

    # Recursively check the paths in separate threads
    directions.each do |direction|
        next if direction[:point] == last_point

        threads << Thread.new do
          new_path = path + direction[:direction]
          find_solutions(direction[:point], new_path.freeze, current_position)
        end
    end

    # Wait for all processes to finish
    threads.each { |thread| thread.join }
  end

  def solution_found(path)
      @solutions << path
  end

end # Solve


def main
  # get started — replace with your login
  start = post_json('/mazebot/race/start', { :login => 'mazebot' })

  maze_path = start['nextMaze']
  # get the first maze
  next_maze = get_json(maze_path)
  # Answer each question, as long as we are correct
  loop do

    solver = Solver.new(next_maze)
    
    # send to mazebot
    solution_result = send_solution(maze_path, solver.shortest_solution)
    case solution_result['result']
    when 'success' then
      maze_path = solution_result['nextMaze']
      next_maze = get_json(maze_path)
    when 'finished' then
      puts "Result ..... #{solution_result['result']}"
      puts "Message .... #{solution_result['message']}"
      puts "Certificate:\n#{build_uri(solution_result['certificate'])}"
      break
    else
      puts "-- Somethign went wrong --"
      pp solution_result
      break
    end
  end

end

def send_solution(path, directions)
  post_json(path, { :directions => directions })
end

# get data from the api and parse it into a ruby hash
def get_json(path)
  puts "*** GET #{path}"

  response = Net::HTTP.get_response(build_uri(path))
  result = JSON.parse(response.body)
  puts "HTTP #{response.code}"

  #puts JSON.pretty_generate(result)
  result
end

# post an answer to the noops api
def post_json(path, body)
  uri = build_uri(path)
  puts "*** POST #{path}"
  puts JSON.pretty_generate(body)

  post_request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  post_request.body = JSON.generate(body)

  response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
    http.request(post_request)
  end

  puts "HTTP #{response.code}"
  result = JSON.parse(response.body)
  puts result[:result]
  result
end

def build_uri(path)
  URI.parse("https://api.noopschallenge.com" + path)
end

main()
