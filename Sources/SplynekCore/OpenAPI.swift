import Foundation

/// Embedded OpenAPI 3.1 spec for Splynek's local HTTP API. Served by
/// the FleetCoordinator at `GET /splynek/v1/openapi.yaml` so CLI,
/// Raycast, Alfred, Shortcuts, curl scripts — anything — can point
/// at a running Splynek and discover the surface.
///
/// The API is a superset of the v0.24 web dashboard endpoints. Read
/// endpoints are open (they expose the same data the LAN Bonjour
/// protocol already shares); mutating endpoints require the fleet
/// token. The token is discoverable via
/// `~/Library/Application Support/Splynek/fleet.json`, which the
/// app writes on listener-ready.
///
/// Design constraint: spec lives next to the code, not in a separate
/// repo. When a route changes, this file changes in the same commit.
enum OpenAPI {

    static let yaml: String = #"""
    openapi: 3.1.0
    info:
      title: Splynek local HTTP API
      description: |
        REST surface for the Splynek macOS download manager. The API is
        served by the fleet coordinator on a loopback + LAN port
        persisted to `~/Library/Application Support/Splynek/fleet.json`.

        Authentication is a single shared secret (`token`) read from
        the same descriptor file. Mutating endpoints require
        `?t=<token>`; read endpoints are open because the fleet
        protocol already exposes the same data over LAN Bonjour.
      version: "1.0.0"
      contact:
        name: Splynek
        url: https://splynek.app
      license:
        name: MIT
    servers:
      - url: http://{host}:{port}
        description: Local Splynek instance
        variables:
          host: { default: "127.0.0.1" }
          port: { default: "0" }
    paths:
      /splynek/v1/status:
        get:
          summary: Fleet status
          description: Returns this device's active + completed downloads.
          responses:
            "200":
              description: OK
              content:
                application/json:
                  schema: { $ref: "#/components/schemas/FleetState" }
      /splynek/v1/openapi.yaml:
        get:
          summary: This spec
          description: Returns the OpenAPI spec you are currently reading.
          responses:
            "200":
              description: OK
              content:
                application/yaml:
                  schema: { type: string }
      /splynek/v1/api/jobs:
        get:
          summary: Active + paused jobs
          description: Subset of the fleet state limited to the `active` field.
          responses:
            "200":
              description: OK
              content:
                application/json:
                  schema: { $ref: "#/components/schemas/JobList" }
      /splynek/v1/api/history:
        get:
          summary: Recent completions
          description: Last N completed downloads, most recent first.
          parameters:
            - name: limit
              in: query
              required: false
              schema: { type: integer, minimum: 1, maximum: 500, default: 25 }
          responses:
            "200":
              description: OK
              content:
                application/json:
                  schema: { $ref: "#/components/schemas/HistoryList" }
      /splynek/v1/api/download:
        post:
          summary: Start a new download
          parameters: [{ $ref: "#/components/parameters/Token" }]
          requestBody:
            required: true
            content:
              application/json:
                schema: { $ref: "#/components/schemas/SubmitRequest" }
          responses:
            "202": { description: Accepted }
            "400": { description: Bad body or invalid URL }
            "401": { description: Missing or wrong token }
      /splynek/v1/api/queue:
        post:
          summary: Append a URL to the persistent queue
          parameters: [{ $ref: "#/components/parameters/Token" }]
          requestBody:
            required: true
            content:
              application/json:
                schema: { $ref: "#/components/schemas/SubmitRequest" }
          responses:
            "202": { description: Accepted }
            "400": { description: Bad body or invalid URL }
            "401": { description: Missing or wrong token }
      /splynek/v1/api/cancel:
        post:
          summary: Cancel every running download
          parameters: [{ $ref: "#/components/parameters/Token" }]
          responses:
            "202": { description: Accepted }
            "401": { description: Missing or wrong token }
    components:
      parameters:
        Token:
          name: t
          in: query
          required: true
          description: Shared secret from fleet.json. Required on mutating endpoints.
          schema: { type: string, minLength: 32, maxLength: 32 }
      schemas:
        SubmitRequest:
          type: object
          required: [url]
          properties:
            url:
              type: string
              format: uri
              description: HTTP(S) URL or `magnet:?` URI.
        FleetState:
          type: object
          required: [device, uuid, port, active, completed]
          properties:
            device: { type: string }
            uuid:   { type: string }
            port:   { type: integer }
            peerCount: { type: integer }
            active:
              type: array
              items: { $ref: "#/components/schemas/ActiveJob" }
            completed:
              type: array
              items: { $ref: "#/components/schemas/CompletedFile" }
        JobList:
          type: array
          items: { $ref: "#/components/schemas/ActiveJob" }
        HistoryList:
          type: array
          items: { $ref: "#/components/schemas/CompletedFile" }
        ActiveJob:
          type: object
          required: [url, filename, outputPath, totalBytes, downloaded, chunkSize, completedChunks]
          properties:
            url:              { type: string, format: uri }
            filename:         { type: string }
            outputPath:       { type: string }
            totalBytes:       { type: integer, format: int64 }
            downloaded:       { type: integer, format: int64 }
            chunkSize:        { type: integer, format: int64 }
            completedChunks:  { type: array, items: { type: integer } }
        CompletedFile:
          type: object
          required: [url, filename, outputPath, totalBytes, finishedAt]
          properties:
            url:        { type: string, format: uri }
            filename:   { type: string }
            outputPath: { type: string }
            totalBytes: { type: integer, format: int64 }
            finishedAt: { type: string, format: date-time }
            sha256:     { type: string, nullable: true }
    """#
}
