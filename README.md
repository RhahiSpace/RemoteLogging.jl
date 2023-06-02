# RemoteLogging

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.rhahi.space/RemoteLogging.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.rhahi.space/RemoteLogging.jl/dev/)
[![Build Status](https://github.com/RhahiSpace/RemoteLogging.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/RhahiSpace/RemoteLogging.jl/actions/workflows/CI.yml?query=branch%3Amain)

RemoteLogging is a logger that can send messages through TCP,
so that a listener set up over the network can display it remotely.

You can:
- Use it like a regular Julia logger.
- Add custom formatting and filtering for the messages.
- Send text messages with color.
- Send ProgressLogging messages.

You cannot:
- Record logs over TCP. You may print the received text into file IO, but
  at this point the metadata about the log messages are lost, so you cannot do
  further processing easily.

## What is it used for?
When writing a program that spams a lot of log messages, and developing
programs interactively, you may want to look at the messages but not right on
the notebook/console you are using right now. RemoteLogging is useful.

## Example use case:

[![Video](https://i.ytimg.com/vi/nsb4yWSy46Q/maxresdefault.jpg)](https://www.youtube.com/watch?v=nsb4yWSy46Q)

Using a custom formatter, an overlay of log messages are visible on the left,
and editor with Julia REPL is used on the right.
