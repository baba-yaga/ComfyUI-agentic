param(
    [Parameter(Mandatory = $true)]
    [string]$WebSocketDebuggerUrl,

    [Parameter(Mandatory = $true)]
    [string]$Expression
)

Add-Type -TypeDefinition @'
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;

public static class LocalCdpClient
{
    public static string Send(string url, string request)
    {
        using (var socket = new ClientWebSocket())
        {
            var endpoint = new Uri(url);
            socket.Options.SetRequestHeader("Origin", "http://" + endpoint.Host + ":" + endpoint.Port);
            socket.ConnectAsync(new Uri(url), CancellationToken.None).GetAwaiter().GetResult();
            var outgoing = new ArraySegment<byte>(Encoding.UTF8.GetBytes(request));
            socket.SendAsync(outgoing, WebSocketMessageType.Text, true, CancellationToken.None).GetAwaiter().GetResult();

            var buffer = new byte[1024 * 1024];
            while (true)
            {
                var count = 0;
                WebSocketReceiveResult result;
                do
                {
                    result = socket.ReceiveAsync(new ArraySegment<byte>(buffer, count, buffer.Length - count), CancellationToken.None).GetAwaiter().GetResult();
                    count += result.Count;
                } while (!result.EndOfMessage);

                var response = Encoding.UTF8.GetString(buffer, 0, count);
                if (response.Contains("\"id\":1"))
                    return response;
            }
        }
    }
}
'@

$request = @{
    id = 1
    method = 'Runtime.evaluate'
    params = @{
        expression = $Expression
        returnByValue = $true
        awaitPromise = $true
        userGesture = $true
    }
} | ConvertTo-Json -Compress -Depth 8

[LocalCdpClient]::Send($WebSocketDebuggerUrl, $request) | ConvertFrom-Json | ConvertTo-Json -Compress -Depth 16
