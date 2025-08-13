import React, { useState } from 'react';
import axios from 'axios';

const UploadCSVPage = () => {
    const [file, setFile] = useState(null);

    const handleFileChange = (e) => {
        setFile(e.target.files[0]);
    };

    const handleUpload = async (e) => {
        e.preventDefault();
        const formData = new FormData();
        formData.append('file', file);

        try {
            const response = await axios.post('/api/upload-csv', formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
            });
            console.log('Upload successful:', response.data);
        } catch (error) {
            console.error('Upload failed:', error);
        }
    };

    return (
        <div>
            <h2>Upload CSV</h2>
            <form onSubmit={handleUpload}>
                <div>
                    <input type="file" accept=".csv" onChange={handleFileChange} required />
                </div>
                <button type="submit">Upload</button>
            </form>
        </div>
    );
};

export default UploadCSVPage;
