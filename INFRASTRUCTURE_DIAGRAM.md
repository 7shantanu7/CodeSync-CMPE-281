# CodeSync Infrastructure Diagram

## Main Architecture Diagram

```mermaid
graph TB
    Internet((Internet))
    Internet --> IGW[Internet Gateway]
    IGW --> RoutePublic[Public Route Table]
    
    subgraph VPC["VPC 10.0.0.0/16"]
        
        subgraph Public["Public Subnet 10.0.1.0/24"]
            RoutePublic --> ALB[Load Balancer]
            RoutePublic --> NAT[NAT Gateway]
        end
        
        NAT --> RoutePrivate[Private Route Table]
        ALB --> App
        RoutePrivate --> App
        
        subgraph App["Private Subnet 10.0.11.0/24"]
            API[API Service<br/>ECS × 2-10]
            WS[WebSocket Service<br/>ECS × 2-10]
        end
        
        RoutePrivate --> Data
        
        subgraph Data["Private Subnet 10.0.21.0/24"]
            DB[(PostgreSQL<br/>Multi-AZ)]
            Cache[(Redis<br/>Cluster)]
        end
        
        API --> DB
        API --> Cache
        WS --> DB
        WS --> Cache
    end
    
    API -.-> AWS[AWS Services:<br/>S3, CloudWatch]
    WS -.-> AWS
    
    Users[Users] --> CDN[CloudFront]
    CDN --> S3[S3 Website]
    Users --> Internet

    style VPC fill:#E8F4F8,stroke:#000,stroke-width:3px,color:#000
    style Public fill:#D5E8D4,stroke:#000,stroke-width:2px,color:#000
    style App fill:#FFE6CC,stroke:#000,stroke-width:2px,color:#000
    style Data fill:#F8CECC,stroke:#000,stroke-width:2px,color:#000
    style Internet fill:#fff,stroke:#000,stroke-width:2px,color:#000
    style IGW fill:#C3E7D8,stroke:#000,color:#000
    style RoutePublic fill:#FFF9C4,stroke:#000,color:#000
    style RoutePrivate fill:#FFF9C4,stroke:#000,color:#000
    style NAT fill:#C3E7D8,stroke:#000,color:#000
    style ALB fill:#F4B183,stroke:#000,color:#000
    style API fill:#FFE6CC,stroke:#000,color:#000
    style WS fill:#FFE6CC,stroke:#000,color:#000
    style DB fill:#B3D9FF,stroke:#000,color:#000
    style Cache fill:#FFB3B3,stroke:#000,color:#000
    style CDN fill:#FFD699,stroke:#000,color:#000
    style S3 fill:#B3E6B3,stroke:#000,color:#000
    style AWS fill:#F0F0F0,stroke:#000,color:#000
    style Users fill:#E0E0E0,stroke:#000,color:#000

    linkStyle default stroke:#000,stroke-width:2px,color:#000
```

## User Registration & Login Flow

```mermaid
sequenceDiagram
    participant U as User
    participant CF as CloudFront
    participant ALB as Load Balancer
    participant API as API Service
    participant RDS as PostgreSQL
    participant Redis as Redis Cache
    
    U->>CF: Access Application
    CF->>U: Serve React App
    
    U->>ALB: POST /api/auth/register
    ALB->>API: Forward Request
    API->>RDS: Check if user exists
    RDS->>API: User not found
    API->>RDS: Create user record
    RDS->>API: User created
    API->>U: 201 Created
    
    U->>ALB: POST /api/auth/login
    ALB->>API: Forward Request
    API->>RDS: Validate credentials
    RDS->>API: User valid
    API->>Redis: Store session (JWT)
    Redis->>API: Session stored
    API->>U: 200 OK + JWT Token
```

## Create & Join Collaborative Document

```mermaid
sequenceDiagram
    participant U1 as User 1
    participant U2 as User 2
    participant ALB as Load Balancer
    participant API as API Service
    participant WS as WebSocket Service
    participant RDS as PostgreSQL
    participant Redis as Redis Cache
    participant S3 as S3 Storage
    
    U1->>ALB: POST /api/documents/create
    ALB->>API: Forward Request
    API->>RDS: Create document record
    RDS->>API: Document created (ID: doc123)
    API->>S3: Store initial snapshot
    S3->>API: Snapshot saved
    API->>U1: 201 Created {documentId: doc123}
    
    U1->>ALB: WebSocket Connect /socket
    ALB->>WS: Establish Connection (sticky)
    WS->>Redis: Store connection mapping
    U1->>WS: JOIN_DOCUMENT {docId: doc123}
    WS->>RDS: Verify permissions
    WS->>Redis: Add user to presence set
    WS->>U1: DOCUMENT_STATE {content, users: [U1]}
    
    U2->>ALB: WebSocket Connect /socket
    ALB->>WS: Establish Connection
    U2->>WS: JOIN_DOCUMENT {docId: doc123}
    WS->>Redis: Add user to presence set
    WS->>U2: DOCUMENT_STATE {content, users: [U1, U2]}
    WS->>U1: USER_JOINED {user: U2}
```

## Real-Time Collaborative Editing

```mermaid
sequenceDiagram
    participant U1 as User 1
    participant WS1 as WebSocket Instance 1
    participant Redis as Redis Pub/Sub
    participant WS2 as WebSocket Instance 2
    participant U2 as User 2
    participant S3 as S3 Storage
    
    U1->>WS1: EDIT_EVENT {docId: doc123, changes: [...]}
    WS1->>Redis: PUBLISH doc:doc123 {changes, userId: U1}
    WS1->>Redis: Store in operational transform cache
    
    Redis->>WS1: Broadcast to subscribers
    Redis->>WS2: Broadcast to subscribers
    
    WS2->>U2: EDIT_EVENT {changes: [...], userId: U1}
    
    Note over WS1,S3: Every 30 seconds or N changes
    WS1->>S3: Store document snapshot
    S3->>WS1: Snapshot saved (versioned)
    
    U2->>WS2: EDIT_EVENT {docId: doc123, changes: [...]}
    WS2->>Redis: PUBLISH doc:doc123 {changes, userId: U2}
    Redis->>WS1: Broadcast
    Redis->>WS2: Broadcast
    WS1->>U1: EDIT_EVENT {changes: [...], userId: U2}
```

---

## How to Use

1. **View Online**: Copy any diagram and paste into https://mermaid.live/
2. **Export**: Download as PNG, SVG, or PDF
3. **Embed**: Use in Markdown files (GitHub, GitLab, Notion, etc.)

