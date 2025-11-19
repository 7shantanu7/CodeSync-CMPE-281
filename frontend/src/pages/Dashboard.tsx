import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import axios from 'axios';

interface Document {
  id: string;
  title: string;
  owner_username: string;
  created_at: string;
  updated_at: string;
}

export default function Dashboard() {
  const [documents, setDocuments] = useState<Document[]>([]);
  const [newDocTitle, setNewDocTitle] = useState('');
  const [showNewDoc, setShowNewDoc] = useState(false);
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    loadDocuments();
  }, []);

  const loadDocuments = async () => {
    try {
      const response = await axios.get('/api/documents');
      setDocuments(response.data.documents);
    } catch (error) {
      console.error('Error loading documents:', error);
    }
  };

  const createDocument = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const response = await axios.post('/api/documents', { title: newDocTitle });
      navigate(`/editor/${response.data.document.id}`);
    } catch (error) {
      console.error('Error creating document:', error);
    }
  };

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>CodeSync</h1>
        <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
          <span style={{ color: '#d4d4d4' }}>
            Welcome, {user?.username}
          </span>
          <button onClick={() => setShowNewDoc(!showNewDoc)} className="btn btn-primary">
            New Document
          </button>
          <button onClick={logout} className="btn btn-secondary">
            Logout
          </button>
        </div>
      </div>

      <div className="dashboard-content">
        {showNewDoc && (
          <div className="document-card" style={{ marginBottom: '2rem' }}>
            <h3>Create New Document</h3>
            <form onSubmit={createDocument} style={{ marginTop: '1rem' }}>
              <div className="form-group">
                <input
                  type="text"
                  placeholder="Document title"
                  value={newDocTitle}
                  onChange={(e) => setNewDocTitle(e.target.value)}
                  required
                  autoFocus
                />
              </div>
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
                <button type="submit" className="btn btn-primary">
                  Create
                </button>
                <button
                  type="button"
                  onClick={() => setShowNewDoc(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        <h2 style={{ color: '#fff', marginBottom: '1rem' }}>Your Documents</h2>
        
        {documents.length === 0 ? (
          <p style={{ color: '#858585' }}>
            No documents yet. Create one to get started!
          </p>
        ) : (
          <div className="documents-grid">
            {documents.map((doc) => (
              <div
                key={doc.id}
                className="document-card"
                onClick={() => navigate(`/editor/${doc.id}`)}
              >
                <h3>{doc.title}</h3>
                <p>Owner: {doc.owner_username}</p>
                <p>Last updated: {new Date(doc.updated_at).toLocaleDateString()}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

