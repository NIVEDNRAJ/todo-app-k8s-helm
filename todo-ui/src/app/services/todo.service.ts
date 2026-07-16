import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { CreateTodoRequest, PagedResult, Todo, UpdateTodoRequest } from '../models/todo.model';

@Injectable({
  providedIn: 'root'
})
export class TodoService {
  private readonly apiUrl = '/api/todo';

  constructor(private http: HttpClient) {}

  getPaged(
    search?: string,
    isCompleted?: boolean,
    pageNumber: number = 1,
    pageSize: number = 10
  ): Observable<PagedResult<Todo>> {
    let params = new HttpParams()
      .set('pageNumber', pageNumber.toString())
      .set('pageSize', pageSize.toString());

    if (search) {
      params = params.set('search', search);
    }
    
    if (isCompleted !== undefined && isCompleted !== null) {
      params = params.set('isCompleted', isCompleted.toString());
    }

    return this.http.get<PagedResult<Todo>>(this.apiUrl, { params });
  }

  getById(id: number): Observable<Todo> {
    return this.http.get<Todo>(`${this.apiUrl}/${id}`);
  }

  create(request: CreateTodoRequest): Observable<Todo> {
    return this.http.post<Todo>(this.apiUrl, request);
  }

  update(id: number, request: UpdateTodoRequest): Observable<Todo> {
    return this.http.put<Todo>(`${this.apiUrl}/${id}`, request);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }
}
