# Websocket protocol for dobaos

## request

Request should has following structure:
`[<req_id>, <method>, <payload>]`

where

`<req_id>` - int or string. So, result with this id will be send to client.

`<method>` - string. request method

`<payload>` - payload specified for each request type

Any request should be valid JSON.

## response

Response will be given
`[<res_id>, <method>, <payload>]`

`res_id` = `req_id`

`method` = `"success"` or `"error"`

`payload` depends on request type. in case of error - error code


## LICENSE

Copyright (c) 2020 Vladimir Shabunin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
