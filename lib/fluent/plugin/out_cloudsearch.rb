require 'aws_cloud_search'

module Fluent
  class Fluent::CloudSearchOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('cloudsearch', self)

    config_param :domain, :string
    config_param :aws_region, :string
    config_param :lang, :string
    config_param :action, :string, :default = 'add'
    config_param :id_key, :stringm :default = 'id'

    # このメソッドは開始前に呼ばれます。
    # 'conf'は設定パラメータを含んだハッシュです。
    # もし設定が無効な場合は、Fluent::ConfigError例外を発生させます。
    def configure(conf)
      super

      @write_proc =
          if @action == 'add'
            lambda {|batch, tag,time,record|
              doc = AWSCloudSearch::Document.new(true)
              doc.lang = @lang
              doc.id = record[id_key]

              record.delete 'id'
              record.each do |k, v|
                doc.add_field(k, v)
              end

              batch.add_document doc
            }
          elsif @action == 'delete'
            lambda {|batch, tag,time,record|
              doc = AWSCloudSearch::Document.new(true)
              doc.id = record[id_key]

              batch.delete_document doc
            }
          else
            raise Fluent::ConfigError.new("Unknown action: #{@action}")
          end
    end

    # このメソッドは開始時に呼ばれます。
    # ここで、ソケットまたはファイルをオープンします。
    def start
      super

    end

    # このメソッドは終了時に呼ばれます。
    # ここで、スレッドを終了し、ソケットまたはファイルをクローズします。
    def shutdown
      super

    end

    # このメソッドはイベントがFluentdに到達時に呼ばれます。
    # イベントをraw文字列に変換します。
    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    # このメソッドはフラッシュインターバル毎に呼ばれます。ここでファイルまたはデータベースに
    # バッファチャンクを書き込みます。
    # 'chunk'は多様な書式化されたイベントを含むバッファチャンクです。
    # あなはすべてのイベントを取得するために'data = chunk.read'を使用でき、
    # IOオブジェクトを取得するために'chunk.open {|io| ... }'を使用できます。
    def write(chunk)
      batch = AWSCloudSearch::DocumentBatch.new
      chunk.msgpack_each do|(tag,time,record)|
        @write_proc.call batch, tag,time,record
      end
      ds = AWSCloudSearch::CloudSearch.new(@domain, @region) #鍵とかは？
      ds.documents_batch(batch)
    end
  end
end