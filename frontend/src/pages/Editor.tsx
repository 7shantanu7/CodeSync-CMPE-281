import { useEffect, useState, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import Editor from '@monaco-editor/react';
import { io, Socket } from 'socket.io-client';

export default function EditorPage() {
  const { documentId } = useParams();
  const { token, user } = useAuth();
  const navigate = useNavigate();
  const [socket, setSocket] = useState<Socket | null>(null);
  const [content, setContent] = useState('');
  const [users, setUsers] = useState<string[]>([]);
  const [documentTitle, setDocumentTitle] = useState('Untitled');
  const editorRef = useRef<any>(null);
  const isRemoteChange = useRef(false);

  useEffect(() => {
    if (!token || !documentId) return;

    // Connect to WebSocket
    const newSocket = io('/', {
      path: '/socket',
      auth: { token },
      transports: ['websocket', 'polling'],
    });

    newSocket.on('connect', () => {
      console.log('Connected to WebSocket');
      newSocket.emit('join-document', { documentId });
    });

    newSocket.on('document-state', (data) => {
      console.log('Received document state:', data);
      setContent(data.content);
      setUsers(data.users);
    });

    newSocket.on('user-joined', (data) => {
      console.log('User joined:', data);
      setUsers((prev) => [...prev, data.username]);
    });

    newSocket.on('user-left', (data) => {
      console.log('User left:', data);
      setUsers((prev) => prev.filter((u) => u !== data.username));
    });

    newSocket.on('edit', (data) => {
      console.log('Received edit:', data);
      if (data.userId !== user?.id && data.changes.content !== undefined) {
        isRemoteChange.current = true;
        setContent(data.changes.content);
      }
    });

    newSocket.on('error', (data) => {
      console.error('Socket error:', data);
      alert(data.message);
      navigate('/dashboard');
    });

    setSocket(newSocket);

    return () => {
      if (documentId) {
        newSocket.emit('leave-document', { documentId });
      }
      newSocket.close();
    };
  }, [token, documentId]);

  const handleEditorChange = (value: string | undefined) => {
    if (isRemoteChange.current) {
      isRemoteChange.current = false;
      return;
    }

    const newContent = value || '';
    setContent(newContent);

    if (socket && documentId) {
      socket.emit('edit', {
        documentId,
        changes: { content: newContent },
        cursor: editorRef.current?.getPosition(),
      });
    }
  };

  const handleEditorMount = (editor: any) => {
    editorRef.current = editor;
  };

  return (
    <div className="editor-container">
      <div className="editor-header">
        <div>
          <span className="editor-title">{documentTitle}</span>
          <button
            onClick={() => navigate('/dashboard')}
            className="btn btn-secondary"
            style={{ marginLeft: '1rem' }}
          >
            Back to Dashboard
          </button>
        </div>
        <div className="users-online">
          <span style={{ color: '#858585', marginRight: '0.5rem' }}>
            Online:
          </span>
          {users.map((username, index) => (
            <span key={index} className="user-badge">
              {username}
            </span>
          ))}
        </div>
      </div>

      <div className="editor-wrapper">
        <Editor
          height="100%"
          defaultLanguage="javascript"
          theme="vs-dark"
          value={content}
          onChange={handleEditorChange}
          onMount={handleEditorMount}
          options={{
            minimap: { enabled: true },
            fontSize: 14,
            wordWrap: 'on',
            automaticLayout: true,
          }}
        />
      </div>
    </div>
  );
}

