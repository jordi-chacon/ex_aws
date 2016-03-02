defmodule ExAws.Kinesis.Client do
  use Behaviour
  alias ExAws.Kinesis.Request

  @moduledoc """
  Defines a Kinesis client.

  Usage:
  ```
  defmodule MyApp.Kinesis do
    use ExAws.Kinesis.Client, otp_app: :my_otp_app
  end
  ```

  In your config
  ```
  config :my_otp_app, :ex_aws,
    kinesis:  [], # kinesis config goes here
    dynamodb: [], # you get the idea
  ```

  You can now use MyApp.Kinesis as the root module for the Kinesis api without needing
  to pass in a particular configuration.
  This enables different otp apps to configure their AWS configuration separately.

  The alignment with a particular OTP app however is entirely optional.
  The following also works:

  ```
  defmodule MyApp.Kinesis do
    use ExAws.Kinesis.Client

    def config_root do
      Application.get_all_env(:my_aws_config_root)
    end
  end
  ```
  ExAws now expects the config for that kinesis client to live under

  ```elixir
  config :my_aws_config_root
    kinesis: [] # Kinesis config goes here
  ```

  Default config values can be found in ExAws.Config

  http://docs.aws.amazon.com/kinesis/latest/APIReference/API_Operations.html
  """

  ## Streams

  @type stream_name :: binary

  @doc "Lists streams"
  defcallback list_streams() :: Request.response_t

  @doc "Describe Stream"
  @type describe_stream_opts :: [
    {:limit, pos_integer} |
    {:exclusive_start_shard_id, binary}
  ]
  defcallback describe_stream(stream_name :: stream_name) :: Request.response_t
  defcallback describe_stream(stream_name :: stream_name, opts :: describe_stream_opts) :: Request.response_t

  @doc """
  Same as describe_stream/1,2 except the shards key is a stream and will automatically handle pagination
  Returns the normally shaped AWS response, except the Shards key is now a stream
  """
  defcallback stream_shards(stream_name :: stream_name) :: Enumerable.t
  defcallback stream_shards(stream_name :: stream_name, opts :: describe_stream_opts) :: Enumerable.t

  @doc "Creates stream"
  defcallback create_stream(stream_name :: stream_name) :: Request.response_t
  defcallback create_stream(stream_name :: stream_name, shard_count :: pos_integer) :: Request.response_t

  @doc "Deletes stream"
  defcallback delete_stream(stream_name :: stream_name) :: Request.response_t

  ## Records

  @doc "Get stream records"
  @type get_records_opts :: [
    {:limit, pos_integer}
  ]
  defcallback get_records(shard_iterator :: binary) :: Request.response_t
  defcallback get_records(shard_iterator :: binary, opts :: get_records_opts) :: Request.response_t

  @doc """
  Returns a stream of kinesis records
  NOTE: This stream is basically INFINITE, in that it runs
  until the shard it is reading from closes, which may be never.
  If you want it to take records until there are no more (at the moment), something like

  ```
  "my-stream"
  |> Kinesis.stream_records
  |> Enum.take_while(fn(val) -> !match?(%{"Data" => []}, val))
  ```
  ought to do the trick.

  The optional iterator_fun is a function that is called after every actual AWS request.
  Generally speaking you won't need this, but it can be handy if you're trying to prevent flooding.
  See Mix.Tasks.Kinesis.Tail.get_records/1 for an example.

  The sleep_between_req_time is the amount of time that this function will sleep between requests to avoid
  exceeding the provisioned read capacity. It defaults to 200ms.
  """
  @type stream_records_opts :: [
    {:limit, pos_integer} |
    {:sleep_between_req_time, non_neg_integer}
  ]
  defcallback stream_records(shard_iterator :: binary) :: Enumerable.t
  defcallback stream_records(shard_iterator :: binary, opts :: stream_records_opts) :: Enumerable.t
  defcallback stream_records(shard_iterator :: binary, opts :: stream_records_opts, each_req_fun :: Fun) :: Enumerable.t

  @doc "Puts a record on a stream"
  @type put_record_opts :: [
    {:explicit_hash_key, binary} |
    {:sequence_number_for_ordering, binary}
  ]
  defcallback put_record(stream_name :: stream_name, partition_key :: binary, data :: binary) :: Request.response_t
  defcallback put_record(stream_name :: stream_name, partition_key :: binary, data :: binary, opts :: put_record_opts) :: Request.response_t

  @doc "Put multiple records on a stream"
  @type put_records_record :: [
    {:data, binary} |
    {:explicit_hash_key, binary}
  ]
  defcallback put_records(stream_name :: stream_name, records :: [put_records_record]) :: Request.response_t

  ## Shards

  @doc """
  Get a shard iterator
  """
  @type shard_iterator_types ::
    :at_sequence_number |
    :after_sequence_number |
    :trim_horizon |
    :latest
  @type get_shard_iterator_opts :: [
    {:starting_sequence_number, binary}
  ]
  defcallback get_shard_iterator(
    stream_name :: stream_name,
    shard_id :: binary,
    shard_iterator_type :: shard_iterator_types) :: Request.response_t
  defcallback get_shard_iterator(
    stream_name :: stream_name,
    shard_id :: binary,
    shard_iterator_type :: shard_iterator_types,
    opts :: get_shard_iterator_opts) :: Request.response_t

  @doc "Merge adjacent shards"
  defcallback merge_shards(stream_name :: stream_name, adjacent_shard_id :: binary, shard_id :: binary) :: Request.response_t

  @doc "Split a shard"
  defcallback split_shard(stream_name :: binary, shard :: binary, new_starting_hash_key :: binary) :: Request.response_t

  ## Tags

  @doc "Add tags to stream"
  @type stream_tags :: [{atom, binary} | {binary, binary}]
  defcallback add_tags_to_stream(stream_name :: binary, tags :: stream_tags) :: Request.response_t

  @doc "Add tags to stream"
  @type list_tags_for_stream_opts :: [
    {:limit, pos_integer} |
    {:exclusive_start_tag_key, binary}
  ]
  defcallback list_tags_for_stream(stream_name :: binary)
  defcallback list_tags_for_stream(stream_name :: binary, opts :: list_tags_for_stream_opts) :: Request.response_t

  @doc "Remove tags from stream"
  defcallback remove_tags_from_stream(stream_name :: binary, tag_keys :: [binary]) :: Request.response_t

  @doc """
  Enables custom request handling.

  By default this just forwards the request to the `ExAws.Kinesis.Request.request/2`.
  However, this can be overriden in your client to provide pre-request adjustments to headers, params, etc.
  """
  defcallback request(client :: %{}, data :: %{}, action :: atom)

  @doc "Retrieves the root AWS config for this client"
  defcallback config_root() :: Keyword.t

  defmacro __using__(opts) do
    boilerplate = __MODULE__
    |> ExAws.Client.generate_boilerplate(opts)

    quote do
      defstruct config: nil, service: :kinesis
      unquote(boilerplate)

      @doc false
      def request(client, action, data) do
        ExAws.Kinesis.Request.request(client, action, data)
      end

      defoverridable config_root: 0, request: 3
    end
  end
end
